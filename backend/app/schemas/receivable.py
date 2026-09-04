from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List


class PrioritizedReceivableResponse(BaseModel):
    receivable_id: str
    counterparty_id: Optional[UUID] = None
    counterparty_name: Optional[str] = None
    amount: Decimal
    currency: str = "INR"
    due_at: datetime
    state: str  # PENDING, DUE_SOON, OVERDUE, SETTLED
    priority: str  # HIGH, MEDIUM, LOW
    reason_codes: List[str] = []
    source_payment_promise_id: UUID

    model_config = ConfigDict(from_attributes=True)
