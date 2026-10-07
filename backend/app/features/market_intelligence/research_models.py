import enum
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from uuid import UUID
from pydantic import BaseModel, Field

from app.infrastructure.market_intelligence.serpapi_models import SerpApiEngine


class ResearchIntent(BaseModel):
    event_id: UUID
    merchant_id: UUID
    event_type: str
    subject: str
    category: Optional[str] = None
    counterparty_name: Optional[str] = None
    operating_city: Optional[str] = None
    operating_state: Optional[str] = None
    business_type: Optional[str] = None
    time_window: str
    reason: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ResearchPlan(BaseModel):
    event_id: UUID
    merchant_id: UUID
    intent: ResearchIntent
    selected_engines: List[SerpApiEngine]
    queries: Dict[str, str]  # engine_name -> sanitized query string
    geographic_context: Optional[str] = None
    time_context: str
    rationale: str
    max_results_per_engine: int = 10
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
