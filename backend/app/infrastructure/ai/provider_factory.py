from app.infrastructure.ai.provider_interface import FinancialIntelligenceProvider
from app.infrastructure.ai.nemotron_provider import NemotronIntelligenceProvider


def get_intelligence_provider() -> FinancialIntelligenceProvider:
    return NemotronIntelligenceProvider()

