from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.features.memory.services.payment_promise_service import PaymentPromiseService
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.schemas.payment_promise import (
    PaymentPromiseCreateRequest,
    PaymentPromiseUpdateRequest,
    PaymentPromiseResponse,
    PromiseFulfillRequest
)
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.models.payment_promise import PromiseStatus
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.post("/payment-promises", response_model=APIResponse)
def create_payment_promise(
    payload: PaymentPromiseCreateRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = PaymentPromiseService(db)
    promise = service.create_promise(merchant.id, payload)
    promise_data = PaymentPromiseResponse.model_validate(promise).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Payment promise recorded",
        data=promise_data
    )


@router.get("/payment-promises", response_model=APIResponse)
def list_payment_promises(
    status: Optional[PromiseStatus] = None,
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = PaymentPromiseRepository(db)
    promises = repo.list_by_merchant(merchant.id, status=status, skip=skip, limit=limit)
    promises_data = [PaymentPromiseResponse.model_validate(p).model_dump(mode="json") for p in promises]
    return APIResponse(
        success=True,
        message="Payment promises retrieved",
        data=promises_data
    )


@router.get("/payment-promises/{id}", response_model=APIResponse)
def get_payment_promise_detail(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = PaymentPromiseRepository(db)
    promise = repo.get_by_id(id, merchant.id)
    if not promise:
        raise NotFoundError("Payment promise not found")

    promise_data = PaymentPromiseResponse.model_validate(promise).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Payment promise detail retrieved",
        data=promise_data
    )


@router.patch("/payment-promises/{id}", response_model=APIResponse)
def update_payment_promise(
    id: UUID,
    payload: PaymentPromiseUpdateRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = PaymentPromiseRepository(db)
    promise = repo.get_by_id(id, merchant.id)
    if not promise:
        raise NotFoundError("Payment promise not found")

    prev_snap = repo._snapshot(promise)
    if payload.description:
        promise.description = payload.description.strip()
    if payload.promised_amount:
        promise.promised_amount = payload.promised_amount
    if payload.due_at:
        promise.due_at = payload.due_at
    if payload.status:
        promise.status = payload.status

    db.commit()
    db.refresh(promise)

    repo.record_event(
        merchant_id=merchant.id,
        payment_promise_id=promise.id,
        event_type="UPDATED",
        previous_snapshot=prev_snap,
        new_snapshot=repo._snapshot(promise)
    )

    promise_data = PaymentPromiseResponse.model_validate(promise).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Payment promise updated",
        data=promise_data
    )


@router.post("/payment-promises/{id}/fulfill", response_model=APIResponse)
def fulfill_payment_promise(
    id: UUID,
    payload: Optional[PromiseFulfillRequest] = None,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = PaymentPromiseService(db)
    ref = payload.fulfillment_reference if payload else None
    promise = service.fulfill_promise(merchant.id, id, ref)
    promise_data = PaymentPromiseResponse.model_validate(promise).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Payment promise explicitly marked fulfilled",
        data=promise_data
    )


@router.post("/payment-promises/{id}/cancel", response_model=APIResponse)
def cancel_payment_promise(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = PaymentPromiseService(db)
    promise = service.cancel_promise(merchant.id, id)
    promise_data = PaymentPromiseResponse.model_validate(promise).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Payment promise cancelled",
        data=promise_data
    )
