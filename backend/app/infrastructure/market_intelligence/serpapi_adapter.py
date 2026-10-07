import logging
from datetime import datetime, timezone
from typing import List, Optional
from app.infrastructure.market_intelligence.provider_interface import MarketIntelligenceProvider
from app.infrastructure.market_intelligence.serpapi_client import SerpApiClient
from app.infrastructure.market_intelligence.serpapi_models import SerpApiResult, SerpApiEngine
from app.schemas.market_intelligence import MarketIngestRequest
from app.models.market_event import MarketEventType

logger = logging.getLogger(__name__)


class SerpApiMarketFeedAdapter(MarketIntelligenceProvider):
    """
    Adapter bridging SerpApiClient with the MarketIntelligenceProvider interface
    and existing MarketEvent / MarketSource persistence pipeline.
    """

    def __init__(self, client: Optional[SerpApiClient] = None):
        self.client = client or SerpApiClient()

    @property
    def provider_name(self) -> str:
        return "SerpApi"

    @property
    def is_available(self) -> bool:
        return self.client.is_configured

    def convert_result_to_ingest_requests(
        self,
        result: SerpApiResult,
        event_type: MarketEventType = MarketEventType.ECONOMIC_EVENT,
        geography: str = "IN",
        sector: Optional[str] = None,
        affected_domains: Optional[List[str]] = None,
    ) -> List[MarketIngestRequest]:
        """
        Converts normalized items from SerpApiResult into MarketIngestRequest models
        ready for the existing MarketEventNormalizationService.
        """
        requests: List[MarketIngestRequest] = []
        now = datetime.now(timezone.utc)

        for item in result.normalized_items:
            # Fallback URL if none provided
            source_url = item.url or f"https://serpapi.com/engine/{result.engine}?q={result.query}"
            source_name = item.source_name or f"SerpApi {result.engine}"
            summary = item.snippet or item.title

            # Persist only compact, essential provenance and evidence fields (Part 3 raw payload audit)
            metadata_info = {
                "engine": result.engine,
                "query": result.query,
                "cached": result.cached,
                "price": item.price,
                "rating": item.rating,
                "reviews": item.reviews,
                "location": item.location,
                "metrics": item.metrics,
                "source_name": source_name,
            }

            requests.append(MarketIngestRequest(
                provider_name=self.provider_name,
                source_name=source_name,
                source_url=source_url,
                title=item.title,
                summary=summary,
                published_at=now,
                event_type=event_type,
                geography=geography,
                sector=sector,
                affected_domains=affected_domains or ["market_prices", "external_evidence"],
                metadata_info=metadata_info
            ))

        return requests

    def fetch_market_events(self) -> List[MarketIngestRequest]:
        """
        Default market event polling when invoked generically.
        If client is unconfigured or no active query, returns empty list safely.
        """
        if not self.is_available:
            return []
        return []
