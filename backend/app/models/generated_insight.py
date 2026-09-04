import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class GeneratedInsight(Base):
    __tablename__ = "generated_insights"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    insight_type = Column(String(50), nullable=False)
    focus_entity_type = Column(String(50), nullable=True)
    focus_entity_id = Column(UUID(as_uuid=True), nullable=True)

    context_version = Column(String(50), nullable=False, default="1.0")
    content = Column(JSONB, nullable=False, default={})
    source_references = Column(JSONB, nullable=False, default=[])
    model_identifier = Column(String(100), nullable=False, default="gemini-1.5-flash")

    status = Column(String(50), nullable=False, default="CURRENT")
    generated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    stale_at = Column(DateTime(timezone=True), nullable=True)

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
        Index("ix_insights_merchant_focus", "merchant_id", "focus_entity_type", "focus_entity_id"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
        if self.generated_at is None:
            self.generated_at = datetime.now(timezone.utc)
        if self.content is None:
            self.content = {}
        if self.source_references is None:
            self.source_references = []
