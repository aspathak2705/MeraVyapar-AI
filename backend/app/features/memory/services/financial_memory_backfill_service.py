from uuid import UUID
from sqlalchemy.orm import Session
from app.repositories.canonical_transaction_repository import CanonicalTransactionRepository
from app.features.memory.services.financial_memory_service import FinancialMemoryService


class FinancialMemoryBackfillService:
    def __init__(self, db: Session):
        self.db = db
        self.canonical_repo = CanonicalTransactionRepository(db)
        self.memory_service = FinancialMemoryService(db)

    def backfill_merchant_memory(self, merchant_id: UUID) -> int:
        txs = self.canonical_repo.list_by_merchant(merchant_id, skip=0, limit=500)
        processed_count = 0

        for tx in txs:
            result = self.memory_service.process_canonical_transaction(tx)
            if result:
                processed_count += 1

        return processed_count
