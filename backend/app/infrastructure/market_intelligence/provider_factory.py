from app.infrastructure.market_intelligence.provider_interface import MarketIntelligenceProvider
from app.infrastructure.market_intelligence.trusted_feed_provider import TrustedMarketFeedProvider


def get_market_intelligence_provider() -> MarketIntelligenceProvider:
    return TrustedMarketFeedProvider()
