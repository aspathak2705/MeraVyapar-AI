from uuid import UUID
import logging
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.gateway.installation_auth import (
    verify_internal_ingest_key,
    verify_installation_request,
    AuthenticatedInstallation,
)
from app.gateway.rate_limiter import rate_limiter
from app.schemas.market_intelligence import (
    MarketIngestRequest,
    MarketIngestResponse,
)
from app.schemas.common import APIResponse

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Market Intelligence"])


@router.post("/market-intelligence/ingest", response_model=APIResponse)
def ingest_market_event_stateless(
    payload: MarketIngestRequest,
    request: Request,
    _authorized: bool = Depends(verify_internal_ingest_key)
):
    """
    Stateless ingestion verification endpoint.
    Validates payload structure and authentication without direct PostgreSQL writes in the gateway.
    """
    client_ip = request.client.host if request.client else "internal"
    rate_limiter.check_rate_limit(client_ip, "/api/v1/market-intelligence/ingest")

    return APIResponse(
        success=True,
        message="Market event received and validated by gateway",
        data={
            "sources_ingested": len(payload.sources),
            "events_created": 1,
            "events_deduplicated": 0,
            "status": "ACCEPTED_STATELESS",
        }
    )

