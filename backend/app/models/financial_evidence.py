import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class EvidenceType(str, enum.Enum):
    MANUAL_ENTRY = "MANUAL_ENTRY"
    PAYMENT_SCREENSHOT = "PAYMENT_SCREENSHOT"
    PAYMENT_RECEIPT = "PAYMENT_RECEIPT"
    BANK_SMS = "BANK_SMS"
    NOTIFICATION = "NOTIFICATION"
    BANK_STATEMENT = "BANK_STATEMENT"
    PAYMENT_PROVIDER_RECORD = "PAYMENT_PROVIDER_RECORD"
    OTHER = "OTHER"


class EvidenceSource(str, enum.Enum):
    MERCHANT_MANUAL = "MERCHANT_MANUAL"
    SHARE_INTENT = "SHARE_INTENT"
    UPLOAD = "UPLOAD"
    SYSTEM_INGESTION = "SYSTEM_INGESTION"
    BANK = "BANK"
    PAYMENT_PROVIDER = "PAYMENT_PROVIDER"


class EvidenceStrength(str, enum.Enum):
    VERIFIED = "VERIFIED"
    STRONG = "STRONG"
    MERCHANT_DECLARED = "MERCHANT_DECLARED"
    AMBIGUOUS = "AMBIGUOUS"
    UNVERIFIED = "UNVERIFIED"


class ProcessingStatus(str, enum.Enum):
    RECEIVED = "RECEIVED"
    VALIDATED = "VALIDATED"
    PROCESSING = "PROCESSING"
    PARSED = "PARSED"
    NORMALIZED = "NORMALIZED"
    AWAITING_EXTRACTION = "AWAITING_EXTRACTION"
    REQUIRES_REVIEW = "REQUIRES_REVIEW"
    FAILED = "FAILED"


class FinancialEvidence(Base):
    __tablename__ = "financial_evidence"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    evidence_type = Column(SQLEnum(EvidenceType, native_enum=False), nullable=False)
    evidence_source = Column(SQLEnum(EvidenceSource, native_enum=False), nullable=False)
    evidence_strength = Column(SQLEnum(EvidenceStrength, native_enum=False), nullable=False)

    raw_text = Column(Text, nullable=True)
    metadata_info = Column("metadata", JSONB, nullable=False, default={})

    storage_object_key = Column(String(512), nullable=True)
    content_type = Column(String(100), nullable=True)
    original_filename = Column(String(255), nullable=True)
    idempotency_key = Column(String(255), nullable=True, index=True)

    processing_status = Column(SQLEnum(ProcessingStatus, native_enum=False), nullable=False, default=ProcessingStatus.RECEIVED)

    received_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    processed_at = Column(DateTime(timezone=True), nullable=True)

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
    candidates = relationship("TransactionCandidate", back_populates="primary_evidence", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_financial_evidence_merchant_created", "merchant_id", "created_at"),
        Index("ix_financial_evidence_status", "processing_status"),
        Index("ix_financial_evidence_type", "evidence_type"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.received_at is None:
            self.received_at = datetime.now(timezone.utc)
        if self.metadata_info is None:
            self.metadata_info = {}
