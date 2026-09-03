import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base import Base


class LinkRelationshipType(str, enum.Enum):
    PRIMARY = "PRIMARY"
    SUPPORTING = "SUPPORTING"
    CONFLICTING = "CONFLICTING"


class TransactionCandidateLink(Base):
    __tablename__ = "transaction_candidate_links"

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
    transaction_candidate_id = Column(
        UUID(as_uuid=True),
        ForeignKey("transaction_candidates.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,  # Candidate maps to max 1 canonical transaction
        index=True
    )

    relationship_type = Column(
        SQLEnum(LinkRelationshipType, native_enum=False),
        nullable=False,
        default=LinkRelationshipType.PRIMARY
    )

    linked_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc)
    )
    linked_by = Column(String(50), nullable=False, default="SYSTEM_RECONCILIATION")

    merchant = relationship("Merchant")
    canonical_transaction = relationship("CanonicalTransaction", back_populates="candidate_links")
    transaction_candidate = relationship("TransactionCandidate")

    __table_args__ = (
        UniqueConstraint("transaction_candidate_id", name="uq_candidate_single_canonical_link"),
        Index("ix_candidate_links_canonical_cand", "canonical_transaction_id", "transaction_candidate_id"),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.id is None:
            self.id = uuid.uuid4()
        if self.linked_at is None:
            self.linked_at = datetime.now(timezone.utc)
