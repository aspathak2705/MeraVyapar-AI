from uuid import UUID
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.repositories.canonical_transaction_repository import CanonicalTransactionRepository
from app.schemas.canonical_transaction import CanonicalTransactionResponse
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.get("/canonical-transactions", response_model=APIResponse)
def list_canonical_transactions(
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CanonicalTransactionRepository(db)
    records = repo.list_by_merchant(merchant.id, skip=skip, limit=limit)
    records_data = [CanonicalTransactionResponse.model_validate(r).model_dump(mode="json") for r in records]
    return APIResponse(
        success=True,
        message="Canonical transactions retrieved",
        data=records_data
    )


@router.get("/canonical-transactions/{id}", response_model=APIResponse)
def get_canonical_transaction_by_id(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CanonicalTransactionRepository(db)
    record = repo.get_by_id(id, merchant.id)
    if not record:
        raise NotFoundError("Canonical transaction not found")

    record_data = CanonicalTransactionResponse.model_validate(record).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Canonical transaction retrieved",
        data=record_data
    )
