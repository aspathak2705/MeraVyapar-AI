from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional
from app.models.transaction_candidate import TransactionType, PaymentMode, NormalizationStatus, ReviewStatus


class TransactionCandidateResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    primary_evidence_id: UUID
    transaction_type: TransactionType
    amount: Optional[Decimal] = None
    currency: str
    transaction_timestamp: Optional[datetime] = None
    counterparty_name: Optional[str] = None
    payment_mode: PaymentMode
    reference_number: Optional[str] = None
    description: Optional[str] = None
    normalization_status: NormalizationStatus
    review_status: ReviewStatus
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
