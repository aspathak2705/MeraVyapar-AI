import re
from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.repositories.counterparty_repository import CounterpartyRepository
from app.models.financial_counterparty import FinancialCounterparty, CounterpartyRelationshipType


class CounterpartyResolutionService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CounterpartyRepository(db)

    @staticmethod
    def normalize_name(raw_name: str) -> str:
        if not raw_name:
            return ""
        # Lowercase, collapse spaces
        cleaned = re.sub(r"\s+", " ", raw_name.strip().lower())
        return cleaned

    def resolve_counterparty(
        self,
        merchant_id: UUID,
        raw_counterparty_name: str,
        relationship_hint: CounterpartyRelationshipType = CounterpartyRelationshipType.UNKNOWN
    ) -> Optional[FinancialCounterparty]:
        if not raw_counterparty_name or not raw_counterparty_name.strip():
            return None

        normalized = self.normalize_name(raw_counterparty_name)
        if not normalized:
            return None

        # 1. Exact alias match
        existing_by_alias = self.repo.get_by_alias(merchant_id, normalized)
        if existing_by_alias:
            return existing_by_alias

        # 2. Exact display name match
        existing_by_name = self.repo.get_by_normalized_name(merchant_id, normalized)
        if existing_by_name:
            return existing_by_name

        # 3. No exact match -> Create new OBSERVED counterparty (No fuzzy guessing!)
        display_name = raw_counterparty_name.strip()
        new_counterparty = self.repo.create_counterparty(
            merchant_id=merchant_id,
            display_name=display_name,
            normalized_name=normalized,
            relationship_type=relationship_hint
        )
        return new_counterparty
