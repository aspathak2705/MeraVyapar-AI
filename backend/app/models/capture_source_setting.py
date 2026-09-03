import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Enum as SQLEnum, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base import Base


class CaptureSourceType(str, enum.Enum):
    NOTIFICATION_CAPTURE = "NOTIFICATION_CAPTURE"
    SMS_CAPTURE = "SMS_CAPTURE"


class CaptureSourceSetting(Base):
    __tablename__ = "capture_source_settings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    merchant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    source_type = Column(SQLEnum(CaptureSourceType, native_enum=False), nullable=False)
    provider_identifier = Column(String(100), nullable=False)
    enabled = Column(Boolean, nullable=False, default=True)

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
        UniqueConstraint("merchant_id", "source_type", "provider_identifier", name="uq_merchant_capture_provider"),
        Index("ix_capture_source_settings_merchant_provider", "merchant_id", "source_type", "provider_identifier"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc)
        if self.updated_at is None:
            self.updated_at = datetime.now(timezone.utc)
