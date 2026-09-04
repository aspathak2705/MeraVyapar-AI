import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class EventType(str, enum.Enum):
    PAYMENT_PROMISE_DUE_SOON = "PAYMENT_PROMISE_DUE_SOON"
    PAYMENT_PROMISE_OVERDUE = "PAYMENT_PROMISE_OVERDUE"
    MULTIPLE_OPEN_PROMISES = "MULTIPLE_OPEN_PROMISES"
    RECEIVABLE_PENDING = "RECEIVABLE_PENDING"
    RECEIVABLE_OVERDUE = "RECEIVABLE_OVERDUE"


class EventSeverity(str, enum.Enum):
    INFO = "INFO"
    ATTENTION = "ATTENTION"
    URGENT = "URGENT"


class EventStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"
    DISMISSED = "DISMISSED"


class FinancialEvent(Base):
    __tablename__ = "financial_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    event_type = Column(
        SQLEnum(EventType, native_enum=False),
        nullable=False
    )
    severity = Column(
        SQLEnum(EventSeverity, native_enum=False),
        nullable=False,
        default=EventSeverity.INFO
    )
    status = Column(
        SQLEnum(EventStatus, native_enum=False),
        nullable=False,
        default=EventStatus.ACTIVE
    )

    title = Column(String(255), nullable=False)
    summary = Column(String(255), nullable=False)

    occurred_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    detected_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    source_entity_type = Column(String(50), nullable=False)
    source_entity_id = Column(UUID(as_uuid=True), nullable=True)

    deduplication_key = Column(String(255), nullable=True)
    metadata_info = Column("metadata", JSONB, nullable=False, default={})

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

    __table_args__ = (
        UniqueConstraint("merchant_id", "deduplication_key", name="uq_merchant_event_dedup"),
        Index("ix_financial_events_merchant_status", "merchant_id", "status"),
        Index("ix_financial_events_type_severity", "event_type", "severity"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.occurred_at is None:
            self.occurred_at = datetime.now(timezone.utc)
        if self.detected_at is None:
            self.detected_at = datetime.now(timezone.utc)
        if self.metadata_info is None:
            self.metadata_info = {}
