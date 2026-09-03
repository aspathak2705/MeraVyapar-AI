import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Numeric, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base import Base
from app.models.transaction_candidate import TransactionType, PaymentMode


class ReconciliationStatus(str, enum.Enum):
    UNRESOLVED = "UNRESOLVED"
    RECONCILED = "RECONCILED"
    REQUIRES_REVIEW = "REQUIRES_REVIEW"


class CanonicalTransaction(Base):
    __tablename__ = "canonical_transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    amount = Column(Numeric(precision=18, scale=2), nullable=True)
    currency = Column(String(3), nullable=False, default="INR")

    transaction_type = Column(SQLEnum(TransactionType, native_enum=False), nullable=False, default=TransactionType.UNKNOWN)
    payment_mode = Column(SQLEnum(PaymentMode, native_enum=False), nullable=False, default=PaymentMode.UNKNOWN)

    counterparty_name = Column(String(255), nullable=True)
    transaction_reference = Column(String(255), nullable=True)

    occurred_at = Column(DateTime(timezone=True), nullable=True)

    reconciliation_status = Column(
        SQLEnum(ReconciliationStatus, native_enum=False),
        nullable=False,
        default=ReconciliationStatus.UNRESOLVED
    )

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc)
    )

    merchant = relationship("Merchant")
    candidate_links = relationship("TransactionCandidateLink", back_populates="canonical_transaction", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_canonical_transactions_merchant_occurred", "merchant_id", "occurred_at"),
        Index("ix_canonical_transactions_status", "reconciliation_status"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
