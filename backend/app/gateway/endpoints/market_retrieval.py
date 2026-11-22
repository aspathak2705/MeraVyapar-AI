import logging
from uuid import UUID, uuid4
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Request, Query

from app.features.market_intelligence.research_planner import sanitize_research_term
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
    query: Optional[str] = Query(None, description="Target market search query"),
    category: Optional[str] = Query(None, description="Business or procurement category"),
    business_type: Optional[str] = Query(None, description="Business type e.g. Kirana, Hardware"),
    city: Optional[str] = Query(None, description="Merchant city"),
    state: Optional[str] = Query(None, description="Merchant state"),
    engine: Optional[str] = Query("google", description="SerpApi engine: google, google_shopping, google_news, google_maps"),
    maps_type: Optional[str] = Query("search", description="Maps search type: search or place"),
    place_id: Optional[str] = Query(None, description="Google Maps place/data ID"),
    installation: AuthenticatedInstallation = Depends(verify_installation_request),
):
    """
    Stateless market intelligence retrieval endpoint.
    Directly queries SerpApi across approved Google engines (Search, Shopping, News, Maps),
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

    # Sanitize all incoming query parameters against PII / financial markers
    clean_query = sanitize_research_term(query)
    clean_category = sanitize_research_term(category)
    clean_biz_type = sanitize_research_term(business_type)
    clean_city = sanitize_research_term(city)
    clean_state = sanitize_research_term(state)

    selected_engine = (engine if isinstance(engine, str) else "google") or "google"
    selected_engine = selected_engine.strip().lower()
    engine_used = selected_engine

    clean_maps_type = (maps_type if isinstance(maps_type, str) else "search") or "search"
    clean_place_id = place_id if isinstance(place_id, str) else None

    if not clean_query:
        query_parts = []
        if clean_biz_type:
            query_parts.append(clean_biz_type)
        elif clean_category:
            query_parts.append(clean_category)

        if selected_engine == SerpApiEngine.SHOPPING.value:
            query_parts.append("wholesale")
        elif selected_engine == SerpApiEngine.NEWS.value:
            query_parts.append("commodity market price supply")
        else:
            query_parts.append("wholesale suppliers distributors")

        if clean_city:
            query_parts.append(clean_city)
        elif clean_state:
            query_parts.append(clean_state)
        else:
            query_parts.append("India")
        clean_query = " ".join([p for p in query_parts if p]).strip()
        if not clean_query:
            clean_query = "wholesale commodity inflation India"

    try:
        if selected_engine == SerpApiEngine.SHOPPING.value:
            result: SerpApiResult = client.shopping(clean_query, num=10)
            items = result.normalized_items
        elif selected_engine == SerpApiEngine.NEWS.value:
            result: SerpApiResult = client.news(clean_query, num=10)
            items = result.normalized_items
        elif selected_engine == SerpApiEngine.MAPS.value:
            query_arg = clean_query if clean_maps_type != "place" or (query and isinstance(query, str) and query.strip()) else None
            result: SerpApiResult = client.maps(
                query_arg,
                maps_type=clean_maps_type,
                place_id=clean_place_id,
                location=clean_city or None,
            )
            items = result.normalized_items
        else:
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

        # Context terms for ranking results
        all_terms = f"{clean_query} {clean_category} {clean_biz_type} {clean_city} {clean_state}".split()
        context_terms = {
            term.lower() for term in all_terms
            if len(term) > 2 and term.lower() not in {'india', 'market', 'retail', 'wholesale', 'price', 'rates'}
        }

        # Event type & evidence nature per engine
        default_event_type = MarketEventType.COMMODITY_PRICE_MOVEMENT.value
        evidence_nature = "DISCOVERED_BUSINESS"
        verification_status = "UNVERIFIED_ONLINE_DISCOVERY"
        explanation = f"Discovered online supplier/business for '{clean_query}'. Note: Unverified web discovery, not an established trade quotation."

        if engine_used == SerpApiEngine.SHOPPING.value:
            default_event_type = MarketEventType.COMMODITY_PRICE_MOVEMENT.value
            evidence_nature = "OBSERVED_ONLINE_LISTING"
            verification_status = "OBSERVED_ONLINE_LISTING_PRICE"
            explanation = f"Observed retail listing price from '{clean_query}'. Note: Online listing price, not a verified trade wholesale quote."
        elif engine_used == SerpApiEngine.NEWS.value:
            default_event_type = MarketEventType.COMMODITY_PRICE_MOVEMENT.value
            evidence_nature = "MARKET_NEWS_REPORT"
            verification_status = "EXTERNAL_MEDIA_REPORT"
            explanation = f"External market news regarding '{clean_query}'. Published by external media source."
        elif engine_used == SerpApiEngine.MAPS.value:
            default_event_type = MarketEventType.SUPPLY_CHAIN_EVENT.value
            evidence_nature = "LOCAL_MARKET_LOCATION"
            verification_status = "UNVERIFIED_LOCAL_POI"
            explanation = f"Local market/supplier location from Google Maps for '{clean_query}'."

        for idx, item in enumerate(items[:10]):
            event_id = uuid4()
            source_id = uuid4()
            relevance_id = uuid4()

            # Preserve actual source publication timestamps
            pub_date_str = getattr(item, "published_date", None)
            item_source_name = getattr(item, "source_name", None) or f"Google {engine_used.capitalize()}"
            item_url = getattr(item, "url", None) or f"https://google.com/search?q={clean_query}"
            item_title = getattr(item, "title", None) or clean_query
            item_snippet = getattr(item, "snippet", None)
            item_price = getattr(item, "price", None)
            item_rating = getattr(item, "rating", None)
            item_reviews = getattr(item, "reviews", None)
            item_location = getattr(item, "location", None)
            item_metrics = getattr(item, "metrics", {}) or {}

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
                "price": item_price,
                "rating": item_rating,
                "reviews": item_reviews,
                "location": item_location,
                "metrics": item_metrics,
                "engine": engine_used,
                "evidence_nature": evidence_nature,
                "verification_status": verification_status,
            }

            ev = {
                "id": str(event_id),
                "event_type": default_event_type,
                "title": item_title,
                "summary": item_snippet or item_title or "Market trend reported by external source.",
                "geography": clean_city or clean_state or "IN",
                "sector": clean_category or clean_biz_type or "Retail & Wholesale",
                "affected_domains": ["INVENTORY", "EXPENSE"],
                "event_status": "ACTIVE",
                "occurred_at": pub_date_str or now.isoformat(),
                "detected_at": now.isoformat(),
                "source_id": str(source_id),
                "source": src,
                "reason_codes": ["EXTERNAL_MARKET_EVIDENCE"],
                "created_at": now.isoformat(),
                "price": item_price,
                "rating": item_rating,
                "reviews": item_reviews,
                "location": item_location,
                "metrics": item_metrics,
                "engine": engine_used,
                "evidence_nature": evidence_nature,
            }

            rel = {
                "id": str(relevance_id),
                "merchant_id": installation.installation_id,
                "market_event_id": str(event_id),
                "relevance_status": MarketRelevanceStatus.POTENTIALLY_RELEVANT.value,
                "reason_codes": ["COMMODITY_PRICE_MONITORING"],
                "explanation": explanation,
                "context_snapshot": {
                    "engine": engine_used,
                    "query": clean_query,
                    "category": clean_category,
                    "business_type": clean_biz_type,
                    "city": clean_city,
                    "state": clean_state,
                    "price": item_price,
                    "rating": item_rating,
                    "location": item_location,
                    "evidence_nature": evidence_nature,
                },
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
