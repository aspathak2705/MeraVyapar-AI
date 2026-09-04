import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class MarketRelevanceStatus(str, enum.Enum):
    NOT_RELEVANT = "NOT_RELEVANT"
    POTENTIALLY_RELEVANT = "POTENTIALLY_RELEVANT"
    REQUIRES_MORE_CONTEXT = "REQUIRES_MORE_CONTEXT"


class MerchantMarketRelevance(Base):
    __tablename__ = "merchant_market_relevance"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    market_event_id = Column(
        UUID(as_uuid=True),
        ForeignKey("market_events.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    relevance_status = Column(
        SQLEnum(MarketRelevanceStatus, native_enum=False),
        nullable=False,
        default=MarketRelevanceStatus.NOT_RELEVANT
    )

    reason_codes = Column(JSONB, nullable=False, default=[])
    context_snapshot = Column(JSONB, nullable=False, default={})

    detected_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    status = Column(String(50), nullable=False, default="ACTIVE")

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
    market_event = relationship("MarketEvent")

    __table_args__ = (
        UniqueConstraint("merchant_id", "market_event_id", name="uq_merchant_market_relevance"),
        Index("ix_merchant_market_relevance_merchant_status", "merchant_id", "status"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.detected_at is None:
            self.detected_at = datetime.now(timezone.utc)
        if self.reason_codes is None:
            self.reason_codes = []
        if self.context_snapshot is None:
            self.context_snapshot = {}
