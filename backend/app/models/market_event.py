import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class MarketEventType(str, enum.Enum):
    INTEREST_RATE_CHANGE = "INTEREST_RATE_CHANGE"
    INFLATION_CHANGE = "INFLATION_CHANGE"
    CURRENCY_MOVEMENT = "CURRENCY_MOVEMENT"
    COMMODITY_PRICE_MOVEMENT = "COMMODITY_PRICE_MOVEMENT"
    GOVERNMENT_POLICY = "GOVERNMENT_POLICY"
    SECTOR_DEVELOPMENT = "SECTOR_DEVELOPMENT"
    PAYMENT_INDUSTRY_CHANGE = "PAYMENT_INDUSTRY_CHANGE"
    BANKING_CHANGE = "BANKING_CHANGE"
    ECONOMIC_EVENT = "ECONOMIC_EVENT"
    SUPPLY_CHAIN_EVENT = "SUPPLY_CHAIN_EVENT"
    OTHER = "OTHER"


class MarketEvent(Base):
    __tablename__ = "market_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_type = Column(
        SQLEnum(MarketEventType, native_enum=False),
        nullable=False,
        default=MarketEventType.OTHER
    )

    title = Column(String(255), nullable=False)
    summary = Column(String(500), nullable=False)

    geography = Column(String(100), nullable=True, default="IN")
    sector = Column(String(100), nullable=True)
    affected_domains = Column(JSONB, nullable=False, default=[])

    event_status = Column(String(50), nullable=False, default="ACTIVE")

    occurred_at = Column(DateTime(timezone=True), nullable=False)
    detected_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    source_id = Column(
        UUID(as_uuid=True),
        ForeignKey("market_sources.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    reason_codes = Column(JSONB, nullable=False, default=[])
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

    source = relationship("MarketSource")

    __table_args__ = (
        Index("ix_market_events_type_occurred", "event_type", "occurred_at"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.event_status is None:
            self.event_status = "ACTIVE"
        if self.geography is None:
            self.geography = "IN"
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.detected_at is None:
            self.detected_at = datetime.now(timezone.utc)
        if self.affected_domains is None:
            self.affected_domains = []
        if self.reason_codes is None:
            self.reason_codes = []
        if self.metadata_info is None:
            self.metadata_info = {}
