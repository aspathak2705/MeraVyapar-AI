from uuid import UUID
from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.repositories.counterparty_repository import CounterpartyRepository
from app.schemas.counterparty import (
    FinancialCounterpartyResponse,
    CounterpartyUpdateRequest,
    FinancialRelationshipEventResponse
)
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.get("/counterparties", response_model=APIResponse)
def list_counterparties(
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CounterpartyRepository(db)
    cps = repo.list_by_merchant(merchant.id, skip=skip, limit=limit)
    cps_data = [FinancialCounterpartyResponse.model_validate(c).model_dump(mode="json") for c in cps]
    return APIResponse(
        success=True,
        message="Financial counterparties retrieved",
        data=cps_data
    )


@router.get("/counterparties/{id}", response_model=APIResponse)
def get_counterparty_detail(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CounterpartyRepository(db)
    cp = repo.get_by_id(id, merchant.id)
    if not cp:
        raise NotFoundError("Financial counterparty not found")

    cp_data = FinancialCounterpartyResponse.model_validate(cp).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Financial counterparty detail retrieved",
        data=cp_data
    )


@router.patch("/counterparties/{id}", response_model=APIResponse)
def update_counterparty(
    id: UUID,
    payload: CounterpartyUpdateRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CounterpartyRepository(db)
    cp = repo.get_by_id(id, merchant.id)
    if not cp:
        raise NotFoundError("Financial counterparty not found")

    if payload.display_name:
        cp.display_name = payload.display_name.strip()
    if payload.relationship_type:
        cp.relationship_type = payload.relationship_type
    if payload.status:
        cp.status = payload.status

    db.commit()
    db.refresh(cp)

    cp_data = FinancialCounterpartyResponse.model_validate(cp).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Financial counterparty updated",
        data=cp_data
    )


@router.get("/counterparties/{id}/timeline", response_model=APIResponse)
def list_counterparty_timeline(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CounterpartyRepository(db)
    cp = repo.get_by_id(id, merchant.id)
    if not cp:
        raise NotFoundError("Financial counterparty not found")

    events = repo.list_timeline(merchant.id, id)
    events_data = [FinancialRelationshipEventResponse.model_validate(e).model_dump(mode="json") for e in events]
    return APIResponse(
        success=True,
        message="Counterparty timeline events retrieved",
        data=events_data
    )
