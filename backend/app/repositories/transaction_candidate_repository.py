from uuid import UUID
from decimal import Decimal
from datetime import datetime
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.transaction_candidate import (
    TransactionCandidate,
    TransactionType,
    PaymentMode,
    NormalizationStatus,
    ReviewStatus
)


class TransactionCandidateRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, candidate_id: UUID, merchant_id: UUID) -> Optional[TransactionCandidate]:
        return self.db.query(TransactionCandidate).filter(
            TransactionCandidate.id == candidate_id,
            TransactionCandidate.merchant_id == merchant_id
        ).first()

    def get_by_evidence_id(self, primary_evidence_id: UUID, merchant_id: UUID) -> Optional[TransactionCandidate]:
        return self.db.query(TransactionCandidate).filter(
            TransactionCandidate.primary_evidence_id == primary_evidence_id,
            TransactionCandidate.merchant_id == merchant_id
        ).first()

    def list_by_merchant(
        self,
        merchant_id: UUID,
        skip: int = 0,
        limit: int = 50
    ) -> List[TransactionCandidate]:
        return self.db.query(TransactionCandidate).filter(
            TransactionCandidate.merchant_id == merchant_id
        ).order_by(TransactionCandidate.created_at.desc()).offset(skip).limit(limit).all()

    def create(
        self,
        merchant_id: UUID,
        primary_evidence_id: UUID,
        transaction_type: TransactionType = TransactionType.UNKNOWN,
        amount: Optional[Decimal] = None,
        currency: str = "INR",
        transaction_timestamp: Optional[datetime] = None,
        counterparty_name: Optional[str] = None,
        payment_mode: PaymentMode = PaymentMode.UNKNOWN,
        reference_number: Optional[str] = None,
        description: Optional[str] = None,
        normalization_status: NormalizationStatus = NormalizationStatus.PENDING,
        review_status: ReviewStatus = ReviewStatus.NOT_REQUIRED
    ) -> TransactionCandidate:
        candidate = TransactionCandidate(
            merchant_id=merchant_id,
            primary_evidence_id=primary_evidence_id,
            transaction_type=transaction_type,
            amount=amount,
            currency=currency,
            transaction_timestamp=transaction_timestamp,
            counterparty_name=counterparty_name,
            payment_mode=payment_mode,
            reference_number=reference_number,
            description=description,
            normalization_status=normalization_status,
            review_status=review_status
        )
        self.db.add(candidate)
        self.db.commit()
        self.db.refresh(candidate)
        return candidate
