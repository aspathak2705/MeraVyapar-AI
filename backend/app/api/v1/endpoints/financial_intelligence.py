from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.features.financial_context.services.context_builder import FinancialContextBuilder
from app.features.financial_context.services.intent_router import DeterministicIntentRouter
from app.features.financial_context.services.insight_persistence_service import InsightPersistenceService
from app.infrastructure.ai.provider_factory import get_intelligence_provider
from app.schemas.financial_context import (
    GroundedInsightResponse,
    FinancialQueryRequest,
    FinancialQueryResponse
)
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.post("/financial-events/{event_id}/explain", response_model=APIResponse)
def explain_financial_event(
    event_id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    builder = FinancialContextBuilder(db)
    context_pkg = builder.build_event_explanation_context(merchant.id, event_id)
    if not context_pkg:
        raise NotFoundError("Financial event not found")

    provider = get_intelligence_provider()
    insight = provider.generate_event_explanation(context_pkg)

    # Persist generated insight
    persistence = InsightPersistenceService(db)
    persistence.save_insight(
        merchant_id=merchant.id,
        insight_type="EVENT_EXPLANATION",
        insight=insight,
        focus_entity_type="financial_event",
        focus_entity_id=event_id
    )

    return APIResponse(
        success=True,
        message="Financial event explanation generated",
        data=insight.model_dump(mode="json")
    )


@router.post("/financial-intelligence/query", response_model=APIResponse)
def query_financial_intelligence(
    payload: FinancialQueryRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    intent_cat, is_allowed, scope_msg = DeterministicIntentRouter.classify_intent(payload.question)

    if not is_allowed:
        query_res = FinancialQueryResponse(
            intent_category=intent_cat,
            is_allowed=False,
            scope_message=scope_msg,
            insight=None
        )
        return APIResponse(
            success=True,
            message="Query processed (out of scope)",
            data=query_res.model_dump(mode="json")
        )

    builder = FinancialContextBuilder(db)
    context_pkg = builder.build_general_query_context(merchant.id, payload.focus_entity_id)

    provider = get_intelligence_provider()
    insight = provider.answer_financial_question(context_pkg, payload.question)

    persistence = InsightPersistenceService(db)
    persistence.save_insight(
        merchant_id=merchant.id,
        insight_type=intent_cat,
        insight=insight,
        focus_entity_type="general",
        focus_entity_id=payload.focus_entity_id
    )

    query_res = FinancialQueryResponse(
        intent_category=intent_cat,
        is_allowed=True,
        scope_message=None,
        insight=insight
    )
    return APIResponse(
        success=True,
        message="Financial query answered cleanly",
        data=query_res.model_dump(mode="json")
    )
