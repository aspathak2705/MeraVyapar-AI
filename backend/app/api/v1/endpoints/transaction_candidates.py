from uuid import UUID
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.services.transaction_candidate_service import TransactionCandidateService
from app.schemas.transaction_candidate import TransactionCandidateResponse
from app.schemas.common import APIResponse
from app.models.merchant import Merchant

router = APIRouter()


@router.get("/transaction-candidates", response_model=APIResponse)
def list_transaction_candidates(
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = TransactionCandidateService(db)
    candidates = service.list_candidates(merchant.id, skip=skip, limit=limit)
    candidates_data = [TransactionCandidateResponse.model_validate(c).model_dump(mode="json") for c in candidates]
    return APIResponse(
        success=True,
        message="Transaction candidates retrieved",
        data=candidates_data
    )


@router.get("/transaction-candidates/{candidate_id}", response_model=APIResponse)
def get_transaction_candidate_by_id(
    candidate_id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = TransactionCandidateService(db)
    candidate = service.get_candidate(candidate_id, merchant.id)
    candidate_data = TransactionCandidateResponse.model_validate(candidate).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Transaction candidate retrieved",
        data=candidate_data
    )
