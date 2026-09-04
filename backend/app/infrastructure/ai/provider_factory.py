from app.infrastructure.ai.provider_interface import FinancialIntelligenceProvider
from app.infrastructure.ai.gemini_provider import GeminiIntelligenceProvider


def get_intelligence_provider() -> FinancialIntelligenceProvider:
    return GeminiIntelligenceProvider()
