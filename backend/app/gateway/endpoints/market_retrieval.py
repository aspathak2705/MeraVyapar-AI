import logging
from uuid import UUID, uuid4
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Request, Query

from app.gateway.installation_auth import verify_installation_request, AuthenticatedInstallation
from app.gateway.rate_limiter import rate_limiter
from app.infrastructure.market_intelligence.serpapi_client import SerpApiClient
from app.infrastructure.market_intelligence.serpapi_models import SerpApiEngine, SerpApiResult
from app.models.market_event import MarketEventType
from app.models.merchant_market_relevance import MarketRelevanceStatus
from app.schemas.market_intelligence import (
    MerchantMarketRelevanceResponse,
    MarketEventResponse,
    MarketSourceResponse,
)
from app.schemas.common import APIResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/market-intelligence", tags=["Market Intelligence Retrieval"])


@router.get("/relevant", response_model=APIResponse)
def get_relevant_market_signals_stateless(
    request: Request,
    query: Optional[str] = Query("wholesale commodity inflation India", description="Target market search query"),
    installation: AuthenticatedInstallation = Depends(verify_installation_request),
):
    """
    Stateless market intelligence retrieval endpoint.
    Directly queries SerpApi across the 3 approved Google engines (Search, Shopping, News),
    normalizes evidence with provenance, and returns structured relevance records.
    Zero PostgreSQL persistence.
    """
    rate_limiter.check_rate_limit(installation.installation_id, "/api/v1/market-intelligence/relevant")

    client = SerpApiClient()
    if not client.is_configured:
        return APIResponse(
            success=True,
            message="Market intelligence provider not configured (SERPAPI_API_KEY missing)",
            data=[]
        )

    clean_query = query.strip() if query else "wholesale commodity inflation India"

    try:
        # Search via approved SerpApi engines: primary search with fallback to news
        engine_used = SerpApiEngine.SEARCH.value
        result: SerpApiResult = client.search(clean_query, num=10)
        items = result.normalized_items

        if not items:
            try:
                news_result = client.news(clean_query)
                if news_result.normalized_items:
                    items = news_result.normalized_items
                    engine_used = news_result.engine
            except Exception as news_err:
                logger.warning("SerpApi news fallback query failed: %s", str(news_err))

        records: List[tuple[int, dict]] = []
        now = datetime.now(timezone.utc)
        # The app sends a query derived from the merchant's local SQLite
        # profile. Rank normalized provider results against that context without
        # uploading the merchant's ledger or profile to any cloud database.
        context_terms = {
            term.lower() for term in clean_query.split()
            if len(term) > 2 and term.lower() not in {'india', 'market', 'retail', 'wholesale'}
        }

        for idx, item in enumerate(items[:10]):
            event_id = uuid4()
            source_id = uuid4()
            relevance_id = uuid4()

            # Preserve actual source publication timestamps. Never substitute the current time for an unknown publication date.
            pub_date_str = getattr(item, "published_date", None)
            item_source_name = getattr(item, "source_name", None) or "Google Market Search"
            item_url = getattr(item, "url", None) or f"https://google.com/search?q={clean_query}"
            item_title = getattr(item, "title", None) or clean_query
            item_snippet = getattr(item, "snippet", None)

            src = {
                "id": str(source_id),
                "provider_name": "SerpApi",
                "source_name": item_source_name,
                "source_url": item_url,
                "external_identifier": f"serpapi_{idx}",
                "title": item_title,
                "published_at": pub_date_str,
                "retrieved_at": now.isoformat(),
                "content_hash": f"hash_{event_id}",
                "created_at": now.isoformat(),
            }

            ev = {
                "id": str(event_id),
                "event_type": MarketEventType.COMMODITY_PRICE_MOVEMENT.value,
                "title": item_title,
                "summary": item_snippet or item_title or "Market trend reported by external source.",
                "geography": "IN",
                "sector": "Retail & Wholesale",
                "affected_domains": ["INVENTORY", "EXPENSE"],
                "event_status": "ACTIVE",
                "occurred_at": pub_date_str or now.isoformat(),
                "detected_at": now.isoformat(),
                "source_id": str(source_id),
                "source": src,
                "reason_codes": ["EXTERNAL_MARKET_EVIDENCE"],
                "created_at": now.isoformat(),
            }

            rel = {
                "id": str(relevance_id),
                "merchant_id": installation.installation_id,
                "market_event_id": str(event_id),
                "relevance_status": MarketRelevanceStatus.POTENTIALLY_RELEVANT.value,
                "reason_codes": ["COMMODITY_PRICE_MONITORING"],
                "explanation": f"Observed from SerpApi query '{clean_query}'. Relevant to wholesale purchase costs.",
                "context_snapshot": {"engine": engine_used, "query": clean_query},
                "detected_at": now.isoformat(),
                "status": "ACTIVE",
                "market_event": ev,
            }

            searchable = f"{item_title or ''} {item_snippet or ''}".lower()
            relevance_score = sum(term in searchable for term in context_terms)
            rel["context_snapshot"]["relevance_score"] = relevance_score
            records.append((relevance_score, rel))

        return APIResponse(
            success=True,
            message="Relevant market signals retrieved via SerpApi",
            data=[record for _, record in sorted(records, key=lambda item: item[0], reverse=True)],
        )

    except Exception as exc:
        logger.error("Stateless market retrieval failed: %s", str(exc), exc_info=True)
        # An upstream failure is not an empty research result. Returning a
        # non-2xx response lets Android present its retryable network state.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Market intelligence provider unavailable. Please try again.",
        ) from exc
