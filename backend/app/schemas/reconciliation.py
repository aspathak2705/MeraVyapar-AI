from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.reconciliation_attempt import ReconciliationDecision


class ReconciliationRunResponse(BaseModel):
    candidates_examined: int
    canonical_transactions_created: int
    candidates_reconciled: int
    candidates_requiring_review: int
    candidates_unresolved: int


class ReconciliationAttemptResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    transaction_candidate_id: UUID
    compared_candidate_id: Optional[UUID] = None
    canonical_transaction_id: Optional[UUID] = None
    decision: ReconciliationDecision
    reason_codes: List[str]
    comparison_snapshot: Dict[str, Any]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
