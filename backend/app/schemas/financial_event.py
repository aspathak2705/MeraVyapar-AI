from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.financial_event import EventType, EventSeverity, EventStatus


class FinancialEventResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    event_type: EventType
    severity: EventSeverity
    status: EventStatus
    title: str
    summary: str
    occurred_at: datetime
    detected_at: datetime
    source_entity_type: str
    source_entity_id: Optional[UUID] = None
    deduplication_key: Optional[str] = None
    metadata_info: Dict[str, Any] = {}
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FinancialEventEvaluationResponse(BaseModel):
    events_evaluated: int
    events_created: int
    events_updated: int
    events_resolved: int
