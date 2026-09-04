import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Text, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class ActionType(str, enum.Enum):
    PAYMENT_REMINDER = "PAYMENT_REMINDER"
    PAYMENT_REQUEST = "PAYMENT_REQUEST"
    FOLLOW_UP_NOTE = "FOLLOW_UP_NOTE"


class CommunicationChannel(str, enum.Enum):
    WHATSAPP = "WHATSAPP"
    SMS = "SMS"
    EMAIL = "EMAIL"
    MANUAL = "MANUAL"


class ActionStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    READY_FOR_REVIEW = "READY_FOR_REVIEW"
    CONFIRMED_BY_MERCHANT = "CONFIRMED_BY_MERCHANT"
    DISPATCH_REQUESTED = "DISPATCH_REQUESTED"
    SENT = "SENT"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class CommunicationAction(Base):
    __tablename__ = "communication_actions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    action_type = Column(
        SQLEnum(ActionType, native_enum=False),
        nullable=False,
        default=ActionType.PAYMENT_REMINDER
    )
    channel = Column(
        SQLEnum(CommunicationChannel, native_enum=False),
        nullable=False,
        default=CommunicationChannel.MANUAL
    )

    related_entity_type = Column(String(50), nullable=False)
    related_entity_id = Column(UUID(as_uuid=True), nullable=True)

    counterparty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_counterparties.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    recipient_identifier = Column(String(255), nullable=True)

    draft_content = Column(Text, nullable=False)
    final_content = Column(Text, nullable=True)

    status = Column(
        SQLEnum(ActionStatus, native_enum=False),
        nullable=False,
        default=ActionStatus.DRAFT
    )

    provider_name = Column(String(50), nullable=True)
    provider_reference = Column(String(255), nullable=True)
    failure_reason = Column(String(500), nullable=True)
    idempotency_key = Column(String(255), nullable=True)

    initiated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    confirmed_at = Column(DateTime(timezone=True), nullable=True)
    executed_at = Column(DateTime(timezone=True), nullable=True)

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
    counterparty = relationship("FinancialCounterparty")

    __table_args__ = (
        UniqueConstraint("merchant_id", "idempotency_key", name="uq_merchant_action_idempotency"),
        Index("ix_communication_actions_merchant_status", "merchant_id", "status"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.initiated_at is None:
            self.initiated_at = datetime.now(timezone.utc)
        if self.metadata_info is None:
            self.metadata_info = {}
