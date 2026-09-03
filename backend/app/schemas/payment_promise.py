from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any
from app.models.payment_promise import (
    PromiseDirection,
    PromiseStatus,
    PromiseSource,
    PromiseEventType
)


class PaymentPromiseCreateRequest(BaseModel):
    counterparty_id: Optional[UUID] = None
    description: str
    promised_amount: Decimal = Field(gt=0, description="Promised amount must be > 0")
    currency: str = "INR"
    promise_direction: PromiseDirection = PromiseDirection.EXPECTED_INCOMING
    due_at: datetime
    source: PromiseSource = PromiseSource.MERCHANT_DECLARED
    source_reference: Optional[str] = None


class PaymentPromiseUpdateRequest(BaseModel):
    description: Optional[str] = None
    promised_amount: Optional[Decimal] = Field(default=None, gt=0)
    due_at: Optional[datetime] = None
    status: Optional[PromiseStatus] = None


class PaymentPromiseEventResponse(BaseModel):
    id: UUID
    event_type: PromiseEventType
    previous_snapshot: Dict[str, Any] = {}
    new_snapshot: Dict[str, Any] = {}
    occurred_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PaymentPromiseResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    counterparty_id: Optional[UUID] = None
    description: str
    promised_amount: Decimal
    currency: str
    promise_direction: PromiseDirection
    due_at: datetime
    status: PromiseStatus
    source: PromiseSource
    source_reference: Optional[str] = None
    fulfilled_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    events: List[PaymentPromiseEventResponse] = []

    model_config = ConfigDict(from_attributes=True)


class PromiseFulfillRequest(BaseModel):
    fulfillment_reference: Optional[str] = None
