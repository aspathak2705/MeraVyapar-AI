from uuid import UUID
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.financial_counterparty import (
    FinancialCounterparty,
    CounterpartyAlias,
    MerchantCounterpartyRelationship,
    TransactionCounterpartyLink,
    FinancialRelationshipEvent,
    CounterpartyRelationshipType,
    CounterpartyStatus,
    MerchantRelationshipStatus,
    CounterpartyLinkType,
    FinancialEventType
)


class CounterpartyRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, counterparty_id: UUID, merchant_id: UUID) -> Optional[FinancialCounterparty]:
        return self.db.query(FinancialCounterparty).filter(
            FinancialCounterparty.id == counterparty_id,
            FinancialCounterparty.merchant_id == merchant_id
        ).first()

    def get_by_normalized_name(self, merchant_id: UUID, normalized_name: str) -> Optional[FinancialCounterparty]:
        return self.db.query(FinancialCounterparty).filter(
            FinancialCounterparty.merchant_id == merchant_id,
            FinancialCounterparty.normalized_name == normalized_name
        ).first()

    def get_by_alias(self, merchant_id: UUID, normalized_alias: str) -> Optional[FinancialCounterparty]:
        alias = self.db.query(CounterpartyAlias).filter(
            CounterpartyAlias.merchant_id == merchant_id,
            CounterpartyAlias.normalized_alias == normalized_alias
        ).first()
        if alias:
            return alias.counterparty
        return None

    def list_by_merchant(self, merchant_id: UUID, skip: int = 0, limit: int = 50) -> List[FinancialCounterparty]:
        return self.db.query(FinancialCounterparty).filter(
            FinancialCounterparty.merchant_id == merchant_id
        ).order_by(FinancialCounterparty.updated_at.desc()).offset(skip).limit(limit).all()

    def create_counterparty(
        self,
        merchant_id: UUID,
        display_name: str,
        normalized_name: str,
        relationship_type: CounterpartyRelationshipType = CounterpartyRelationshipType.UNKNOWN
    ) -> FinancialCounterparty:
        cp = FinancialCounterparty(
            merchant_id=merchant_id,
            display_name=display_name,
            normalized_name=normalized_name,
            relationship_type=relationship_type,
            status=CounterpartyStatus.ACTIVE
        )
        self.db.add(cp)
        self.db.commit()
        self.db.refresh(cp)

        # Create alias for self
        alias = CounterpartyAlias(
            merchant_id=merchant_id,
            counterparty_id=cp.id,
            alias_value=display_name,
            normalized_alias=normalized_name,
            source="EXACT_MATCH"
        )
        self.db.add(alias)

        # Create merchant relationship profile
        rel = MerchantCounterpartyRelationship(
            merchant_id=merchant_id,
            counterparty_id=cp.id,
            relationship_type=relationship_type,
            relationship_status=MerchantRelationshipStatus.OBSERVED,
            transaction_count=0
        )
        self.db.add(rel)
        cp.relationship_profile = rel
        self.db.commit()
        self.db.refresh(cp)
        return cp

    def add_alias(
        self,
        merchant_id: UUID,
        counterparty_id: UUID,
        alias_value: str,
        normalized_alias: str,
        source: str = "MERCHANT_CORRECTION"
    ) -> CounterpartyAlias:
        existing = self.db.query(CounterpartyAlias).filter(
            CounterpartyAlias.merchant_id == merchant_id,
            CounterpartyAlias.normalized_alias == normalized_alias
        ).first()
        if existing:
            return existing

        alias = CounterpartyAlias(
            merchant_id=merchant_id,
            counterparty_id=counterparty_id,
            alias_value=alias_value,
            normalized_alias=normalized_alias,
            source=source
        )
        self.db.add(alias)
        self.db.commit()
        self.db.refresh(alias)
        return alias

    def is_transaction_linked(self, canonical_transaction_id: UUID) -> bool:
        link = self.db.query(TransactionCounterpartyLink).filter(
            TransactionCounterpartyLink.canonical_transaction_id == canonical_transaction_id,
            TransactionCounterpartyLink.link_type == CounterpartyLinkType.PRIMARY_COUNTERPARTY
        ).first()
        return link is not None

    def link_transaction(
        self,
        merchant_id: UUID,
        canonical_transaction_id: UUID,
        counterparty_id: UUID,
        link_type: CounterpartyLinkType = CounterpartyLinkType.PRIMARY_COUNTERPARTY
    ) -> TransactionCounterpartyLink:
        existing = self.db.query(TransactionCounterpartyLink).filter(
            TransactionCounterpartyLink.canonical_transaction_id == canonical_transaction_id,
            TransactionCounterpartyLink.link_type == link_type
        ).first()
        if existing:
            return existing

        link = TransactionCounterpartyLink(
            merchant_id=merchant_id,
            canonical_transaction_id=canonical_transaction_id,
            counterparty_id=counterparty_id,
            link_type=link_type
        )
        self.db.add(link)

        # Increment relationship transaction count and last_seen_at
        rel = self.db.query(MerchantCounterpartyRelationship).filter(
            MerchantCounterpartyRelationship.merchant_id == merchant_id,
            MerchantCounterpartyRelationship.counterparty_id == counterparty_id
        ).first()
        if rel:
            rel.transaction_count += 1
            rel.last_seen_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(link)
        return link

    def record_event(
        self,
        merchant_id: UUID,
        counterparty_id: UUID,
        event_type: FinancialEventType,
        canonical_transaction_id: Optional[UUID] = None,
        payment_promise_id: Optional[UUID] = None,
        occurred_at: Optional[datetime] = None,
        metadata_info: Optional[Dict[str, Any]] = None
    ) -> FinancialRelationshipEvent:
        event = FinancialRelationshipEvent(
            merchant_id=merchant_id,
            counterparty_id=counterparty_id,
            event_type=event_type,
            canonical_transaction_id=canonical_transaction_id,
            payment_promise_id=payment_promise_id,
            occurred_at=occurred_at or datetime.now(timezone.utc),
            metadata_info=metadata_info or {}
        )
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event

    def list_timeline(self, merchant_id: UUID, counterparty_id: UUID) -> List[FinancialRelationshipEvent]:
        return self.db.query(FinancialRelationshipEvent).filter(
            FinancialRelationshipEvent.merchant_id == merchant_id,
            FinancialRelationshipEvent.counterparty_id == counterparty_id
        ).order_by(FinancialRelationshipEvent.occurred_at.desc()).all()
