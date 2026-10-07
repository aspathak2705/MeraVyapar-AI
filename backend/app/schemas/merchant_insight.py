from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any


class ExternalEvidenceReferenceResponse(BaseModel):
    evidence_id: str
    source_name: Optional[str] = None
    engine: Optional[str] = None
    title: Optional[str] = None
    snippet: Optional[str] = None
    source_url: Optional[str] = None
    price: Optional[str] = None
    rating: Optional[float] = None
    location: Optional[str] = None
    published_at: Optional[datetime] = None
    retrieved_at: Optional[datetime] = None
    claim: Optional[str] = None


class InternalFactResponse(BaseModel):
    fact_id: str
    label: str
    value: str
    metric_name: str
    current_value: Optional[str] = None
    comparison_value: Optional[str] = None
    percentage_change: Optional[str] = None


class MerchantInsightResponse(BaseModel):
    id: UUID
    insight_type: str
    title: str
    summary: str
    financial_facts: List[InternalFactResponse] = []
    external_signals: List[ExternalEvidenceReferenceResponse] = []
    interpretation: str
    grounding_status: str
    evidence_references: List[str] = []
    limitations: List[str] = []
    focus_entity_id: Optional[UUID] = None
    focus_entity_type: Optional[str] = None
    generated_at: datetime
    status: str = "CURRENT"

    model_config = ConfigDict(from_attributes=True)
