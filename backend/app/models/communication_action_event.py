import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class CommunicationAuditEvent(Base):
    __tablename__ = "communication_action_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    communication_action_id = Column(
        UUID(as_uuid=True),
        ForeignKey("communication_actions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    event_type = Column(String(50), nullable=False)
    previous_status = Column(String(50), nullable=True)
    new_status = Column(String(50), nullable=False)

    actor_type = Column(String(50), nullable=False, default="MERCHANT")
    metadata_info = Column("metadata", JSONB, nullable=False, default={})

    occurred_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )

    communication_action = relationship("CommunicationAction")

    __table_args__ = (
        Index("ix_action_events_action_id", "communication_action_id", "occurred_at"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.occurred_at is None:
            self.occurred_at = datetime.now(timezone.utc)
        if self.metadata_info is None:
            self.metadata_info = {}
