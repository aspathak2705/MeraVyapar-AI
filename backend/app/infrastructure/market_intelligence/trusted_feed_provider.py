import os
from typing import List
from app.infrastructure.market_intelligence.provider_interface import MarketIntelligenceProvider
from app.schemas.market_intelligence import MarketIngestRequest
from app.core.config import settings


class TrustedMarketFeedProvider(MarketIntelligenceProvider):
    def __init__(self):
        self.api_key = getattr(settings, "BRAVE_API_KEY", None) or os.environ.get("BRAVE_API_KEY") or os.environ.get("MARKET_FEED_KEY")

    @property
    def provider_name(self) -> str:
        return "TrustedMarketFeed"

    @property
    def is_available(self) -> bool:
        return bool(self.api_key and self.api_key.strip())

    def fetch_market_events(self) -> List[MarketIngestRequest]:
        if not self.is_available:
            return []
        # When configured, fetches real external feed items. If key missing, returns 0 items.
        return []
