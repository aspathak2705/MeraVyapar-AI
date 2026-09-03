from uuid import UUID
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.reconciliation_attempt import ReconciliationAttempt, ReconciliationDecision


class ReconciliationRepository:
    def __init__(self, db: Session):
        self.db = db

    def record_attempt(
        self,
        merchant_id: UUID,
        transaction_candidate_id: UUID,
        decision: ReconciliationDecision,
        compared_candidate_id: Optional[UUID] = None,
        canonical_transaction_id: Optional[UUID] = None,
        reason_codes: Optional[List[str]] = None,
        comparison_snapshot: Optional[Dict[str, Any]] = None
    ) -> ReconciliationAttempt:
        attempt = ReconciliationAttempt(
            merchant_id=merchant_id,
            transaction_candidate_id=transaction_candidate_id,
            compared_candidate_id=compared_candidate_id,
            canonical_transaction_id=canonical_transaction_id,
            decision=decision,
            reason_codes=reason_codes or [],
            comparison_snapshot=comparison_snapshot or {}
        )
        self.db.add(attempt)
        self.db.commit()
        self.db.refresh(attempt)
        return attempt

    def list_by_merchant(self, merchant_id: UUID, skip: int = 0, limit: int = 50) -> List[ReconciliationAttempt]:
        return self.db.query(ReconciliationAttempt).filter(
            ReconciliationAttempt.merchant_id == merchant_id
        ).order_by(ReconciliationAttempt.created_at.desc()).offset(skip).limit(limit).all()
