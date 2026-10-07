import enum
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from uuid import UUID
from pydantic import BaseModel, Field


class GroundingStatus(str, enum.Enum):
    STRONGLY_SUPPORTED = "STRONGLY_SUPPORTED"
    SUPPORTED = "SUPPORTED"
    POTENTIAL_CONNECTION = "POTENTIAL_CONNECTION"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"
    CONFLICTING_EVIDENCE = "CONFLICTING_EVIDENCE"
    AI_INSIGHT_UNAVAILABLE = "AI_INSIGHT_UNAVAILABLE"


class InsightType(str, enum.Enum):
    EXPENSE_PRESSURE_EXPLAINED = "EXPENSE_PRESSURE_EXPLAINED"
    REVENUE_CHANGE_CONTEXT = "REVENUE_CHANGE_CONTEXT"
    CATEGORY_MARKET_SIGNAL = "CATEGORY_MARKET_SIGNAL"
    LOCAL_MARKET_CONTEXT = "LOCAL_MARKET_CONTEXT"
    MACRO_CONTEXT = "MACRO_CONTEXT"
    INSUFFICIENT_EXTERNAL_EVIDENCE = "INSUFFICIENT_EXTERNAL_EVIDENCE"


class EvidenceFreshness(str, enum.Enum):
    FRESH = "FRESH"
    RECENT = "RECENT"
    STALE = "STALE"
    UNKNOWN = "UNKNOWN"


# Layer 1: Internal Financial Fact
class InternalFinancialFact(BaseModel):
    fact_id: str
    label: str
    value: str
    metric_name: str
    current_value: Optional[str] = None
    comparison_value: Optional[str] = None
    percentage_change: Optional[str] = None
    period_start: Optional[str] = None
    period_end: Optional[str] = None


# Layer 2: External Market Signal
class ExternalMarketSignal(BaseModel):
    evidence_id: str  # Stable ID (content_hash or market_source UUID)
    source_name: str
    engine: str
    title: str
    snippet: Optional[str] = None
    source_url: Optional[str] = None
    published_at: Optional[datetime] = None
    retrieved_at: Optional[datetime] = None
    freshness: EvidenceFreshness = EvidenceFreshness.UNKNOWN
    price: Optional[str] = None
    rating: Optional[float] = None
    location: Optional[str] = None
    metrics: Dict[str, Any] = Field(default_factory=dict)


# Grounded Evidence Bundle
class GroundedEvidenceBundle(BaseModel):
    bundle_id: str = Field(default_factory=lambda: str(UUID(int=0)))
    merchant_id: UUID
    financial_event_id: UUID
    event_type: str
    event_title: str
    event_summary: str
    reference_period: str
    comparison_period: Optional[str] = None
    category: Optional[str] = None
    counterparty_name: Optional[str] = None
    operating_city: Optional[str] = None
    operating_state: Optional[str] = None
    business_type: Optional[str] = None
    research_status: str = "SUCCESS"  # SUCCESS, PARTIAL_SUCCESS, NO_EVIDENCE, FAILED
    internal_facts: List[InternalFinancialFact] = Field(default_factory=list)
    external_evidence: List[ExternalMarketSignal] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# Grounded Evidence Reference in Model Output
class GroundedEvidenceReference(BaseModel):
    evidence_id: str
    claim: str


# Structured Merchant Insight
class GroundedMerchantInsight(BaseModel):
    insight_type: InsightType
    title: str
    summary: str
    financial_facts: List[InternalFinancialFact] = Field(default_factory=list)
    external_signals: List[GroundedEvidenceReference] = Field(default_factory=list)
    interpretation: str
    grounding_status: GroundingStatus
    evidence_references: List[str] = Field(default_factory=list)  # List of referenced evidence_ids
    limitations: List[str] = Field(default_factory=list)
    model_metadata: Dict[str, Any] = Field(default_factory=dict)
    generated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
