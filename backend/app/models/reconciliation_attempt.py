import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class ReconciliationDecision(str, enum.Enum):
    MATCHED = "MATCHED"
    NOT_MATCHED = "NOT_MATCHED"
    REQUIRES_REVIEW = "REQUIRES_REVIEW"
    SKIPPED = "SKIPPED"


class ReconciliationAttempt(Base):
    __tablename__ = "reconciliation_attempts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    transaction_candidate_id = Column(
        UUID(as_uuid=True),
        ForeignKey("transaction_candidates.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    compared_candidate_id = Column(
        UUID(as_uuid=True),
        ForeignKey("transaction_candidates.id", ondelete="SET NULL"),
        nullable=True
    )
    canonical_transaction_id = Column(
        UUID(as_uuid=True),
        ForeignKey("canonical_transactions.id", ondelete="SET NULL"),
        nullable=True
    )

    decision = Column(
        SQLEnum(ReconciliationDecision, native_enum=False),
        nullable=False
    )
    reason_codes = Column(JSONB, nullable=False, default=[])
    comparison_snapshot = Column(JSONB, nullable=False, default={})

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    merchant = relationship("Merchant")
    transaction_candidate = relationship("TransactionCandidate", foreign_keys=[transaction_candidate_id])
    compared_candidate = relationship("TransactionCandidate", foreign_keys=[compared_candidate_id])
    canonical_transaction = relationship("CanonicalTransaction")

    __table_args__ = (
        Index("ix_reconciliation_attempts_merchant_created", "merchant_id", "created_at"),
        Index("ix_reconciliation_attempts_cand", "transaction_candidate_id"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.reason_codes is None:
            self.reason_codes = []
        if self.comparison_snapshot is None:
            self.comparison_snapshot = {}
