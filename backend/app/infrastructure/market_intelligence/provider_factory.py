from app.infrastructure.market_intelligence.provider_interface import MarketIntelligenceProvider
from app.infrastructure.market_intelligence.trusted_feed_provider import TrustedMarketFeedProvider
from app.infrastructure.market_intelligence.serpapi_adapter import SerpApiMarketFeedAdapter
from app.core.config import settings


def get_market_intelligence_provider() -> MarketIntelligenceProvider:
    if settings.SERPAPI_API_KEY and settings.SERPAPI_API_KEY.strip():
        return SerpApiMarketFeedAdapter()
    return TrustedMarketFeedProvider()

