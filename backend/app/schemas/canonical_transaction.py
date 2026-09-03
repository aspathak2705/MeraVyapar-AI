from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from app.models.transaction_candidate import TransactionType, PaymentMode
from app.models.canonical_transaction import ReconciliationStatus
from app.models.transaction_candidate_link import LinkRelationshipType
from app.schemas.transaction_candidate import TransactionCandidateResponse


class CandidateLinkSummary(BaseModel):
    id: UUID
    transaction_candidate_id: UUID
    relationship_type: LinkRelationshipType
    linked_at: datetime
    linked_by: str
    candidate: Optional[TransactionCandidateResponse] = None

    model_config = ConfigDict(from_attributes=True)


class CanonicalTransactionResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    amount: Optional[Decimal] = None
    currency: str
    transaction_type: TransactionType
    payment_mode: PaymentMode
    counterparty_name: Optional[str] = None
    transaction_reference: Optional[str] = None
    occurred_at: Optional[datetime] = None
    reconciliation_status: ReconciliationStatus
    created_at: datetime
    updated_at: datetime
    candidate_links: List[CandidateLinkSummary] = []

    model_config = ConfigDict(from_attributes=True)
