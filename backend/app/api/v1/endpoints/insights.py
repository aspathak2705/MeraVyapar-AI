import uuid
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.models.merchant import Merchant
from app.models.generated_insight import GeneratedInsight
from app.models.market_source import MarketSource
from app.schemas.common import APIResponse
from app.schemas.merchant_insight import (
    MerchantInsightResponse,
    InternalFactResponse,
    ExternalEvidenceReferenceResponse,
)
from app.core.exceptions import NotFoundError

router = APIRouter()


def _format_insight_response(insight: GeneratedInsight, db: Session) -> MerchantInsightResponse:
    content = insight.content or {}

    # Extract internal facts
    raw_facts = content.get("financial_facts", [])
    facts = [InternalFactResponse.model_validate(f) for f in raw_facts if isinstance(f, dict)]

    # Enrich external signals with details from MarketSource if available
    raw_signals = content.get("external_signals", [])
    signals: List[ExternalEvidenceReferenceResponse] = []

    for sig in raw_signals:
        if not isinstance(sig, dict):
            continue
        ev_id = sig.get("evidence_id")
        claim = sig.get("claim")

        # Try looking up source by UUID
        src = None
        if ev_id:
            try:
                src_uuid = UUID(ev_id)
                src = db.query(MarketSource).filter(MarketSource.id == src_uuid).first()
            except Exception:
                src = db.query(MarketSource).filter(MarketSource.content_hash == ev_id).first()

        if src:
            src_meta = src.raw_metadata or {}
            signals.append(ExternalEvidenceReferenceResponse(
                evidence_id=str(ev_id),
                source_name=src.source_name,
                engine=src_meta.get("engine"),
                title=src.title,
                snippet=src_meta.get("snippet"),
                source_url=src.source_url,
                price=src_meta.get("price"),
                rating=src_meta.get("rating"),
                location=src_meta.get("location"),
                published_at=src.published_at,
                retrieved_at=src.retrieved_at,
                claim=claim
            ))
        else:
            signals.append(ExternalEvidenceReferenceResponse(
                evidence_id=str(ev_id),
                claim=claim
            ))

    return MerchantInsightResponse(
        id=insight.id,
        insight_type=insight.insight_type,
        title=content.get("title", "Financial Insight"),
        summary=content.get("summary", ""),
        financial_facts=facts,
        external_signals=signals,
        interpretation=content.get("interpretation", ""),
        grounding_status=content.get("grounding_status", "SUPPORTED"),
        evidence_references=content.get("evidence_references", []),
        limitations=content.get("limitations", []),
        focus_entity_id=insight.focus_entity_id,
        focus_entity_type=insight.focus_entity_type,
        generated_at=insight.generated_at,
        status=insight.status
    )


@router.get("/insights", response_model=APIResponse)
def list_merchant_insights(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    """
    Lists generated merchant insights ordered deterministically by generated_at DESC.
    Guarantees strict merchant isolation.
    """
    insights = db.query(GeneratedInsight).filter(
        GeneratedInsight.merchant_id == merchant.id,
        GeneratedInsight.status == "CURRENT"
    ).order_by(GeneratedInsight.generated_at.desc()).offset(skip).limit(limit).all()

    formatted = [_format_insight_response(ins, db).model_dump(mode="json") for ins in insights]
    return APIResponse(
        success=True,
        message="Merchant insights retrieved",
        data=formatted
    )


@router.get("/insights/{insight_id}", response_model=APIResponse)
def get_merchant_insight_detail(
    insight_id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    """
    Retrieves detail of a specific insight with verified merchant ownership.
    """
    insight = db.query(GeneratedInsight).filter(
        GeneratedInsight.id == insight_id,
        GeneratedInsight.merchant_id == merchant.id
    ).first()

    if not insight:
        raise NotFoundError("Insight not found")

    formatted = _format_insight_response(insight, db).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Insight detail retrieved",
        data=formatted
    )
