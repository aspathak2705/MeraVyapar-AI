import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Enum as SQLEnum, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class CounterpartyRelationshipType(str, enum.Enum):
    UNKNOWN = "UNKNOWN"
    CUSTOMER = "CUSTOMER"
    VENDOR = "VENDOR"
    EMPLOYEE = "EMPLOYEE"
    SERVICE_PROVIDER = "SERVICE_PROVIDER"
    OTHER = "OTHER"


class CounterpartyStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"
    POSSIBLE_DUPLICATE = "POSSIBLE_DUPLICATE"


class MerchantRelationshipStatus(str, enum.Enum):
    OBSERVED = "OBSERVED"
    CONFIRMED = "CONFIRMED"
    ARCHIVED = "ARCHIVED"


class CounterpartyLinkType(str, enum.Enum):
    PRIMARY_COUNTERPARTY = "PRIMARY_COUNTERPARTY"
    POSSIBLE_COUNTERPARTY = "POSSIBLE_COUNTERPARTY"


class FinancialEventType(str, enum.Enum):
    FIRST_TRANSACTION = "FIRST_TRANSACTION"
    PAYMENT_RECEIVED = "PAYMENT_RECEIVED"
    PAYMENT_SENT = "PAYMENT_SENT"
    RELATIONSHIP_CONFIRMED = "RELATIONSHIP_CONFIRMED"
    ALIAS_ADDED = "ALIAS_ADDED"
    PAYMENT_PROMISE_CREATED = "PAYMENT_PROMISE_CREATED"
    PAYMENT_PROMISE_UPDATED = "PAYMENT_PROMISE_UPDATED"
    PAYMENT_PROMISE_FULFILLED = "PAYMENT_PROMISE_FULFILLED"
    PAYMENT_PROMISE_OVERDUE = "PAYMENT_PROMISE_OVERDUE"


class FinancialCounterparty(Base):
    __tablename__ = "financial_counterparties"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    display_name = Column(String(255), nullable=False)
    normalized_name = Column(String(255), nullable=False)

    relationship_type = Column(
        SQLEnum(CounterpartyRelationshipType, native_enum=False),
        nullable=False,
        default=CounterpartyRelationshipType.UNKNOWN
    )
    status = Column(
        SQLEnum(CounterpartyStatus, native_enum=False),
        nullable=False,
        default=CounterpartyStatus.ACTIVE
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
    aliases = relationship("CounterpartyAlias", back_populates="counterparty", cascade="all, delete-orphan")
    relationship_profile = relationship("MerchantCounterpartyRelationship", back_populates="counterparty", uselist=False, cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_counterparties_merchant_normalized", "merchant_id", "normalized_name"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)


class CounterpartyAlias(Base):
    __tablename__ = "counterparty_aliases"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    counterparty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_counterparties.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    alias_value = Column(String(255), nullable=False)
    normalized_alias = Column(String(255), nullable=False)
    source = Column(String(50), nullable=False, default="EXACT_MATCH")

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    merchant = relationship("Merchant")
    counterparty = relationship("FinancialCounterparty", back_populates="aliases")

    __table_args__ = (
        UniqueConstraint("merchant_id", "normalized_alias", name="uq_merchant_normalized_alias"),
        Index("ix_aliases_merchant_normalized", "merchant_id", "normalized_alias"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)


class MerchantCounterpartyRelationship(Base):
    __tablename__ = "merchant_counterparty_relationships"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    counterparty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_counterparties.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True
    )

    relationship_type = Column(
        SQLEnum(CounterpartyRelationshipType, native_enum=False),
        nullable=False,
        default=CounterpartyRelationshipType.UNKNOWN
    )
    relationship_status = Column(
        SQLEnum(MerchantRelationshipStatus, native_enum=False),
        nullable=False,
        default=MerchantRelationshipStatus.OBSERVED
    )

    first_seen_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    last_seen_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    transaction_count = Column(Integer, nullable=False, default=0)

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
    counterparty = relationship("FinancialCounterparty", back_populates="relationship_profile")

    __table_args__ = (
        UniqueConstraint("merchant_id", "counterparty_id", name="uq_merchant_counterparty_rel"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.first_seen_at is None:
            self.first_seen_at = datetime.now(timezone.utc)
        if self.last_seen_at is None:
            self.last_seen_at = datetime.now(timezone.utc)


class TransactionCounterpartyLink(Base):
    __tablename__ = "transaction_counterparty_links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    canonical_transaction_id = Column(
        UUID(as_uuid=True),
        ForeignKey("canonical_transactions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    counterparty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_counterparties.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    link_type = Column(
        SQLEnum(CounterpartyLinkType, native_enum=False),
        nullable=False,
        default=CounterpartyLinkType.PRIMARY_COUNTERPARTY
    )

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    merchant = relationship("Merchant")
    canonical_transaction = relationship("CanonicalTransaction")
    counterparty = relationship("FinancialCounterparty")

    __table_args__ = (
        UniqueConstraint("canonical_transaction_id", "link_type", name="uq_canonical_primary_counterparty"),
        Index("ix_tx_counterparty_links_tx", "canonical_transaction_id"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)


class FinancialRelationshipEvent(Base):
    __tablename__ = "financial_relationship_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    counterparty_id = Column(
        UUID(as_uuid=True),
        ForeignKey("financial_counterparties.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    event_type = Column(
        SQLEnum(FinancialEventType, native_enum=False),
        nullable=False
    )
    canonical_transaction_id = Column(
        UUID(as_uuid=True),
        ForeignKey("canonical_transactions.id", ondelete="SET NULL"),
        nullable=True
    )
    payment_promise_id = Column(
        UUID(as_uuid=True),
        ForeignKey("payment_promises.id", ondelete="SET NULL"),
        nullable=True
    )

    occurred_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    metadata_info = Column("metadata", JSONB, nullable=False, default={})

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    merchant = relationship("Merchant")
    counterparty = relationship("FinancialCounterparty")

    __table_args__ = (
        Index("ix_relationship_events_merchant_counterparty", "merchant_id", "counterparty_id", "occurred_at"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.occurred_at is None:
            self.occurred_at = datetime.now(timezone.utc)
        if self.metadata_info is None:
            self.metadata_info = {}
