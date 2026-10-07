import enum
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from uuid import UUID
from pydantic import BaseModel, Field

from app.infrastructure.market_intelligence.serpapi_models import SerpApiEngine, ExternalEvidenceItem


class ExecutionStatus(str, enum.Enum):
    SUCCESS = "SUCCESS"
    PARTIAL_SUCCESS = "PARTIAL_SUCCESS"
    FAILED = "FAILED"
    NO_EVIDENCE = "NO_EVIDENCE"


class EngineExecutionDetail(BaseModel):
    engine: str
    query: str
    status: str  # "SUCCESS", "TIMEOUT", "RATE_LIMITED", "ERROR", "NO_EVIDENCE"
    evidence_count: int = 0
    cached: bool = False
    error_message: Optional[str] = None


class ResearchExecutionResult(BaseModel):
    plan_id: Optional[UUID] = None
    event_id: UUID
    merchant_id: UUID
    status: ExecutionStatus
    engines_attempted: List[str] = Field(default_factory=list)
    engines_succeeded: List[str] = Field(default_factory=list)
    engines_failed: List[str] = Field(default_factory=list)
    evidence_count: int = 0
    persisted_sources_count: int = 0
    persisted_events_count: int = 0
    persisted_relevances_count: int = 0
    engine_details: List[EngineExecutionDetail] = Field(default_factory=list)
    failure_summary: Optional[str] = None
    executed_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
