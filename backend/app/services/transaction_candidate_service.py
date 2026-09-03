from uuid import UUID
from typing import List
from sqlalchemy.orm import Session
from app.repositories.transaction_candidate_repository import TransactionCandidateRepository
from app.models.transaction_candidate import TransactionCandidate
from app.core.exceptions import NotFoundError


class TransactionCandidateService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = TransactionCandidateRepository(db)

    def get_candidate(self, candidate_id: UUID, merchant_id: UUID) -> TransactionCandidate:
        candidate = self.repo.get_by_id(candidate_id, merchant_id)
        if not candidate:
            raise NotFoundError("Transaction candidate not found")
        return candidate

    def list_candidates(self, merchant_id: UUID, skip: int = 0, limit: int = 50) -> List[TransactionCandidate]:
        return self.repo.list_by_merchant(merchant_id, skip=skip, limit=limit)
