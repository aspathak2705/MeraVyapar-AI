import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID, JSONB
from app.db.base import Base


class MarketSource(Base):
    __tablename__ = "market_sources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider_name = Column(String(50), nullable=False)
    source_name = Column(String(100), nullable=False)
    source_url = Column(String(500), nullable=False)
    external_identifier = Column(String(255), nullable=True)

    title = Column(String(255), nullable=False)
    published_at = Column(DateTime(timezone=True), nullable=False)
    retrieved_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    content_hash = Column(String(64), nullable=False)
    raw_metadata = Column("metadata", JSONB, nullable=False, default={})

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    __table_args__ = (
        UniqueConstraint("provider_name", "content_hash", name="uq_market_source_provider_hash"),
        Index("ix_market_sources_provider_published", "provider_name", "published_at"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.retrieved_at is None:
            self.retrieved_at = datetime.now(timezone.utc)
        if self.raw_metadata is None:
            self.raw_metadata = {}
