from abc import ABC, abstractmethod
from typing import List
from app.schemas.market_intelligence import MarketIngestRequest


class MarketIntelligenceProvider(ABC):
    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass

    @property
    @abstractmethod
    def is_available(self) -> bool:
        pass

    @abstractmethod
    def fetch_market_events(self) -> List[MarketIngestRequest]:
        pass
