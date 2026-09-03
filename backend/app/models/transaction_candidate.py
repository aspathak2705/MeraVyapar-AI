import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Numeric, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base import Base


class TransactionType(str, enum.Enum):
    MONEY_IN = "MONEY_IN"
    MONEY_OUT = "MONEY_OUT"
    UNKNOWN = "UNKNOWN"


class PaymentMode(str, enum.Enum):
    UPI = "UPI"
    BANK_TRANSFER = "BANK_TRANSFER"
    CARD = "CARD"
    CASH = "CASH"
    CHEQUE = "CHEQUE"
    NET_BANKING = "NET_BANKING"
    WALLET = "WALLET"
    OTHER = "OTHER"
    UNKNOWN = "UNKNOWN"


class NormalizationStatus(str, enum.Enum):
    PENDING = "PENDING"
    NORMALIZED = "NORMALIZED"
    FAILED = "FAILED"


class ReviewStatus(str, enum.Enum):
    NOT_REQUIRED = "NOT_REQUIRED"
    REQUIRES_REVIEW = "REQUIRES_REVIEW"
    CONFIRMED = "CONFIRMED"
    REJECTED = "REJECTED"


class TransactionCandidate(Base):
    __tablename__ = "transaction_candidates"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    primary_evidence_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_evidence.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    transaction_type = Column(SQLEnum(TransactionType, native_enum=False), nullable=False, default=TransactionType.UNKNOWN)

    # Monetary precision: NUMERIC(18,2), never float
    amount = Column(Numeric(precision=18, scale=2), nullable=True)
    currency = Column(String(3), nullable=False, default="INR")

    transaction_timestamp = Column(DateTime(timezone=True), nullable=True)

    counterparty_name = Column(String(255), nullable=True)
    payment_mode = Column(SQLEnum(PaymentMode, native_enum=False), nullable=False, default=PaymentMode.UNKNOWN)
    reference_number = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)

    normalization_status = Column(SQLEnum(NormalizationStatus, native_enum=False), nullable=False, default=NormalizationStatus.PENDING)
    review_status = Column(SQLEnum(ReviewStatus, native_enum=False), nullable=False, default=ReviewStatus.NOT_REQUIRED)

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
    primary_evidence = relationship("FinancialEvidence", back_populates="candidates")

    __table_args__ = (
        Index("ix_transaction_candidates_merchant_timestamp", "merchant_id", "transaction_timestamp"),
        Index("ix_transaction_candidates_type", "transaction_type"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
