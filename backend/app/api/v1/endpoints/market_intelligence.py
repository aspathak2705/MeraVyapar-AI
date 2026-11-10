from uuid import UUID
from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant, verify_internal_ingest_key
from app.repositories.market_intelligence_repository import MarketIntelligenceRepository
from app.features.market_intelligence.services.normalization_service import MarketEventNormalizationService
from app.features.market_intelligence.services.context_builder import MerchantMarketContextBuilder
from app.features.market_intelligence.services.relevance_engine import MarketRelevanceRuleEngine
from app.schemas.market_intelligence import (
    MarketSourceResponse,
    MarketEventResponse,
    MerchantMarketRelevanceResponse,
    MarketIngestRequest,
    MarketIngestResponse
)
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.models.merchant_market_relevance import MarketRelevanceStatus
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.post("/market-intelligence/ingest", response_model=APIResponse)
def ingest_market_event(
    payload: MarketIngestRequest,
    db: Session = Depends(get_db),
    _authorized: bool = Depends(verify_internal_ingest_key)
):
    service = MarketEventNormalizationService(db)
    event, created = service.ingest_market_event(payload)

    return APIResponse(
        success=True,
        message="Market event ingested" if created else "Market event deduplicated",
        data={
            "sources_ingested": 1 if created else 0,
            "events_created": 1 if created else 0,
            "events_deduplicated": 0 if created else 1,
            "market_event_id": str(event.id)
        }
    )


@router.get("/market-events", response_model=APIResponse)
def list_market_events(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    repo = MarketIntelligenceRepository(db)
    events = repo.list_market_events(skip=skip, limit=limit)
    events_data = [MarketEventResponse.model_validate(e).model_dump(mode="json") for e in events]
    return APIResponse(
        success=True,
        message="Market events retrieved",
        data=events_data
    )


@router.get("/market-intelligence/relevant", response_model=APIResponse)
def get_relevant_market_signals(
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = MarketIntelligenceRepository(db)
    context_builder = MerchantMarketContextBuilder(db)
    merchant_context = context_builder.build_merchant_market_context(merchant.id)

    # Evaluate all active market events against current merchant context
    all_events = repo.list_market_events(skip=0, limit=100)
    for ev in all_events:
        rel_status, reason_codes, explanation = MarketRelevanceRuleEngine.evaluate_relevance(ev, merchant_context)
        if rel_status in (MarketRelevanceStatus.POTENTIALLY_RELEVANT, MarketRelevanceStatus.REQUIRES_MORE_CONTEXT):
            ctx_snapshot = merchant_context.to_dict()
            ctx_snapshot["explanation"] = explanation
            repo.create_or_update_relevance(
                merchant_id=merchant.id,
                market_event_id=ev.id,
                relevance_status=rel_status,
                reason_codes=reason_codes,
                context_snapshot=ctx_snapshot
            )

    relevant_records = repo.list_relevant_for_merchant(merchant.id, skip=skip, limit=limit)
    res_list = []
    for r in relevant_records:
        r_dict = MerchantMarketRelevanceResponse.model_validate(r).model_dump(mode="json")
        r_dict["explanation"] = r.context_snapshot.get("explanation")
        res_list.append(r_dict)

    return APIResponse(
        success=True,
        message="Relevant market signals retrieved",
        data=res_list
    )


@router.get("/market-intelligence/relevance/{id}", response_model=APIResponse)
def get_market_relevance_detail(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = MarketIntelligenceRepository(db)
    relevance = repo.get_relevance(merchant.id, id)
    if not relevance:
        raise NotFoundError("Market relevance record not found")

    r_dict = MerchantMarketRelevanceResponse.model_validate(relevance).model_dump(mode="json")
    r_dict["explanation"] = relevance.context_snapshot.get("explanation")
    return APIResponse(
        success=True,
        message="Market relevance detail retrieved",
        data=r_dict
    )
