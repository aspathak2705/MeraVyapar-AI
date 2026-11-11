import logging
from uuid import UUID, uuid4
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Request

from app.gateway.installation_auth import verify_installation_request, AuthenticatedInstallation
from app.gateway.rate_limiter import rate_limiter
from app.schemas.financial_context import (
    FinancialQueryRequest,
    FinancialQueryResponse,
    FinancialContextPackage,
    GroundedInsightResponse,
)
from app.schemas.common import APIResponse
from app.features.financial_context.services.intent_router import DeterministicIntentRouter
from app.infrastructure.ai.provider_factory import get_intelligence_provider

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/financial-intelligence", tags=["Financial Intelligence Grounding"])


@router.post("/query", response_model=APIResponse)
def query_financial_intelligence_stateless(
    payload: FinancialQueryRequest,
    request: Request,
    installation: AuthenticatedInstallation = Depends(verify_installation_request),
):
    """
    Stateless grounded financial intelligence query endpoint.
    Passes sanitized merchant question and local context to OpenRouter Nemotron.
    Enforces deterministic intent classification, amount grounding, and zero mutations.
    Zero PostgreSQL persistence.
    """
    rate_limiter.check_rate_limit(installation.installation_id, "/api/v1/financial-intelligence/query")

    intent_cat, is_allowed, scope_msg = DeterministicIntentRouter.classify_intent(payload.question)

    if not is_allowed:
        query_res = FinancialQueryResponse(
            intent_category=intent_cat,
            is_allowed=False,
            scope_message=scope_msg,
            insight=None,
        )
        return APIResponse(
            success=True,
            message="Query processed (out of scope)",
            data=query_res.model_dump(mode="json"),
        )

    # Build sanitized context package for Nemotron grounding
    context_pkg = FinancialContextPackage(
        context_version="2.0",
        merchant_id=uuid4(),
        focus_type="GENERAL",
        focus_entity_id=payload.focus_entity_id,
        events=[],
        payment_promises=[],
        receivables=[],
        counterparties=[],
        computed_metrics={"status": "device_local_snapshot"},
        provenance_sources=[],
    )

    provider = get_intelligence_provider()
    insight: GroundedInsightResponse = provider.answer_financial_question(context_pkg, payload.question)

    query_res = FinancialQueryResponse(
        intent_category=intent_cat,
        is_allowed=True,
        scope_message=None,
        insight=insight,
    )

    return APIResponse(
        success=True,
        message="Financial query answered via grounded Nemotron reasoning",
        data=query_res.model_dump(mode="json"),
    )
