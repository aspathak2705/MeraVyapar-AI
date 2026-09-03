import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Numeric, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class PromiseDirection(str, enum.Enum):
    EXPECTED_INCOMING = "EXPECTED_INCOMING"
    EXPECTED_OUTGOING = "EXPECTED_OUTGOING"


class PromiseStatus(str, enum.Enum):
    OPEN = "OPEN"
    FULFILLED = "FULFILLED"
    OVERDUE = "OVERDUE"
    CANCELLED = "CANCELLED"


class PromiseSource(str, enum.Enum):
    MERCHANT_DECLARED = "MERCHANT_DECLARED"
    EXPLICIT_EVIDENCE = "EXPLICIT_EVIDENCE"


class PromiseEventType(str, enum.Enum):
    CREATED = "CREATED"
    UPDATED = "UPDATED"
    FULFILLED = "FULFILLED"
    CANCELLED = "CANCELLED"
    OVERDUE = "OVERDUE"


class PaymentPromise(Base):
    __tablename__ = "payment_promises"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    counterparty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_counterparties.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    description = Column(String(255), nullable=False)
    promised_amount = Column(Numeric(precision=18, scale=2), nullable=False)
    currency = Column(String(3), nullable=False, default="INR")

    promise_direction = Column(
        SQLEnum(PromiseDirection, native_enum=False),
        nullable=False,
        default=PromiseDirection.EXPECTED_INCOMING
    )
    due_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(
        SQLEnum(PromiseStatus, native_enum=False),
        nullable=False,
        default=PromiseStatus.OPEN
    )

    source = Column(
        SQLEnum(PromiseSource, native_enum=False),
        nullable=False,
        default=PromiseSource.MERCHANT_DECLARED
    )
    source_reference = Column(String(255), nullable=True)

    fulfilled_at = Column(DateTime(timezone=True), nullable=True)

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
    counterparty = relationship("FinancialCounterparty")
    events = relationship("PaymentPromiseEvent", back_populates="payment_promise", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_payment_promises_merchant_due", "merchant_id", "due_at"),
        Index("ix_payment_promises_status", "status"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)


class PaymentPromiseEvent(Base):
    __tablename__ = "payment_promise_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    payment_promise_id = Column(
        UUID(as_uuid=True),
        ForeignKey("payment_promises.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    event_type = Column(
        SQLEnum(PromiseEventType, native_enum=False),
        nullable=False
    )

    previous_snapshot = Column(JSONB, nullable=False, default={})
    new_snapshot = Column(JSONB, nullable=False, default={})

    occurred_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    merchant = relationship("Merchant")
    payment_promise = relationship("PaymentPromise", back_populates="events")

    __table_args__ = (
        Index("ix_promise_events_promise", "payment_promise_id"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.occurred_at is None:
            self.occurred_at = datetime.now(timezone.utc)
        if self.previous_snapshot is None:
            self.previous_snapshot = {}
        if self.new_snapshot is None:
            self.new_snapshot = {}
