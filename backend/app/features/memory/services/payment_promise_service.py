from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from sqlalchemy.orm import Session
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.models.payment_promise import PaymentPromise, PromiseDirection, PromiseStatus, PromiseSource
from app.models.financial_counterparty import FinancialEventType
from app.schemas.payment_promise import PaymentPromiseCreateRequest, PaymentPromiseUpdateRequest
from app.core.exceptions import NotFoundError, ValidationError


class PaymentPromiseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = PaymentPromiseRepository(db)
        self.cp_repo = CounterpartyRepository(db)

    def create_promise(self, merchant_id: UUID, req: PaymentPromiseCreateRequest) -> PaymentPromise:
        if req.promised_amount <= Decimal("0"):
            raise ValidationError("Promised amount must be greater than 0")

        if req.counterparty_id:
            cp = self.cp_repo.get_by_id(req.counterparty_id, merchant_id)
            if not cp:
                raise NotFoundError("Linked counterparty not found")

        promise = self.repo.create(
            merchant_id=merchant_id,
            counterparty_id=req.counterparty_id,
            description=req.description,
            promised_amount=req.promised_amount,
            currency=req.currency,
            promise_direction=req.promise_direction,
            due_at=req.due_at,
            source=req.source,
            source_reference=req.source_reference
        )

        if promise.counterparty_id:
            self.cp_repo.record_event(
                merchant_id=merchant_id,
                counterparty_id=promise.counterparty_id,
                event_type=FinancialEventType.PAYMENT_PROMISE_CREATED,
                payment_promise_id=promise.id,
                occurred_at=promise.created_at,
                metadata_info={"amount": str(promise.promised_amount), "description": promise.description}
            )

        return promise

    def fulfill_promise(self, merchant_id: UUID, promise_id: UUID, fulfillment_ref: Optional[str] = None) -> PaymentPromise:
        promise = self.repo.get_by_id(promise_id, merchant_id)
        if not promise:
            raise NotFoundError("Payment promise not found")

        fulfilled_promise = self.repo.fulfill(promise, fulfillment_ref)

        if fulfilled_promise.counterparty_id:
            self.cp_repo.record_event(
                merchant_id=merchant_id,
                counterparty_id=fulfilled_promise.counterparty_id,
                event_type=FinancialEventType.PAYMENT_PROMISE_FULFILLED,
                payment_promise_id=fulfilled_promise.id,
                metadata_info={"fulfillment_reference": fulfillment_ref}
            )

        return fulfilled_promise

    def cancel_promise(self, merchant_id: UUID, promise_id: UUID) -> PaymentPromise:
        promise = self.repo.get_by_id(promise_id, merchant_id)
        if not promise:
            raise NotFoundError("Payment promise not found")

        return self.repo.cancel(promise)
