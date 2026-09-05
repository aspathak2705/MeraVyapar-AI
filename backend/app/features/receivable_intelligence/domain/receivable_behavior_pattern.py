from pydantic import BaseModel, ConfigDict
from uuid import UUID
from typing import Optional, List, Dict, Any


class CounterpartyBehaviorResponse(BaseModel):
    counterparty_id: UUID
    counterparty_name: Optional[str] = None
    pattern_type: str  # CONSISTENT_ON_TIME, OCCASIONAL_DELAY, REPEATED_DELAY, PARTIAL_PAYMENT_PATTERN, PROMISE_KEPT_PATTERN, PROMISE_BROKEN_PATTERN, INSUFFICIENT_HISTORY
    total_promises_observed: int = 0
    kept_count: int = 0
    broken_count: int = 0
    overdue_count: int = 0
    reason_codes: List[str] = []
    explanation: str
    status: str = "AVAILABLE"

    model_config = ConfigDict(from_attributes=True)
