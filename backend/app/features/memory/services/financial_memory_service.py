from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.models.canonical_transaction import CanonicalTransaction
from app.models.financial_counterparty import (
    FinancialCounterparty,
    FinancialEventType,
    CounterpartyRelationshipType
)
from app.repositories.counterparty_repository import CounterpartyRepository
from app.features.memory.services.counterparty_resolution_service import CounterpartyResolutionService


class FinancialMemoryService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CounterpartyRepository(db)
        self.resolution_service = CounterpartyResolutionService(db)

    def process_canonical_transaction(self, canonical_tx: CanonicalTransaction) -> Optional[FinancialCounterparty]:
        if not canonical_tx.counterparty_name or not canonical_tx.counterparty_name.strip():
            return None

        # Check idempotency: if already linked, skip duplicate memory building
        if self.repo.is_transaction_linked(canonical_tx.id):
            return None

        # Derive relationship hint based on direction
        hint = CounterpartyRelationshipType.UNKNOWN
        if canonical_tx.transaction_type == "MONEY_IN":
            hint = CounterpartyRelationshipType.CUSTOMER
        elif canonical_tx.transaction_type == "MONEY_OUT":
            hint = CounterpartyRelationshipType.VENDOR

        cp = self.resolution_service.resolve_counterparty(
            merchant_id=canonical_tx.merchant_id,
            raw_counterparty_name=canonical_tx.counterparty_name,
            relationship_hint=hint
        )

        if not cp:
            return None

        # Link transaction (this increments relationship transaction_count)
        link = self.repo.link_transaction(
            merchant_id=canonical_tx.merchant_id,
            canonical_transaction_id=canonical_tx.id,
            counterparty_id=cp.id
        )

        # Check updated transaction count from relationship profile
        rel = cp.relationship_profile
        tx_count = rel.transaction_count if rel else 1

        event_type = FinancialEventType.FIRST_TRANSACTION if tx_count == 1 else (
            FinancialEventType.PAYMENT_RECEIVED if canonical_tx.transaction_type == "MONEY_IN" else FinancialEventType.PAYMENT_SENT
        )

        self.repo.record_event(
            merchant_id=canonical_tx.merchant_id,
            counterparty_id=cp.id,
            event_type=event_type,
            canonical_transaction_id=canonical_tx.id,
            occurred_at=canonical_tx.occurred_at or canonical_tx.created_at,
            metadata_info={
                "amount": str(canonical_tx.amount) if canonical_tx.amount is not None else None,
                "currency": canonical_tx.currency,
                "payment_mode": canonical_tx.payment_mode
            }
        )

        return cp
