from abc import ABC, abstractmethod
from typing import Optional
from app.schemas.financial_context import FinancialContextPackage, GroundedInsightResponse


class FinancialIntelligenceProvider(ABC):
    @property
    @abstractmethod
    def is_available(self) -> bool:
        pass

    @abstractmethod
    def generate_event_explanation(self, context_package: FinancialContextPackage) -> GroundedInsightResponse:
        pass

    @abstractmethod
    def answer_financial_question(self, context_package: FinancialContextPackage, question: str) -> GroundedInsightResponse:
        pass
