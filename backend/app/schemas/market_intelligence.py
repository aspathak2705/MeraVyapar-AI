from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.market_event import MarketEventType
from app.models.merchant_market_relevance import MarketRelevanceStatus


class MarketSourceResponse(BaseModel):
    id: UUID
    provider_name: str
    source_name: str
    source_url: str
    external_identifier: Optional[str] = None
    title: str
    published_at: datetime
    retrieved_at: datetime
    content_hash: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class MarketEventResponse(BaseModel):
    id: UUID
    event_type: MarketEventType
    title: str
    summary: str
    geography: Optional[str] = None
    sector: Optional[str] = None
    affected_domains: List[str] = []
    event_status: str
    occurred_at: datetime
    detected_at: datetime
    source_id: UUID
    source: Optional[MarketSourceResponse] = None
    reason_codes: List[str] = []
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class MerchantMarketRelevanceResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    market_event_id: UUID
    relevance_status: MarketRelevanceStatus
    reason_codes: List[str] = []
    explanation: Optional[str] = None
    context_snapshot: Dict[str, Any] = {}
    detected_at: datetime
    status: str
    market_event: Optional[MarketEventResponse] = None

    model_config = ConfigDict(from_attributes=True)


class MarketIngestRequest(BaseModel):
    provider_name: str
    source_name: str
    source_url: str
    title: str
    summary: str
    published_at: datetime
    event_type: Optional[MarketEventType] = MarketEventType.OTHER
    geography: Optional[str] = "IN"
    sector: Optional[str] = None
    affected_domains: List[str] = []
    metadata_info: Dict[str, Any] = {}


class MarketIngestResponse(BaseModel):
    sources_ingested: int
    events_created: int
    events_deduplicated: int
