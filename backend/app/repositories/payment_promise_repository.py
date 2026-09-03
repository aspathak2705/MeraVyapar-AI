from uuid import UUID
from datetime import datetime, timezone
from decimal import Decimal
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.payment_promise import (
    PaymentPromise,
    PaymentPromiseEvent,
    PromiseDirection,
    PromiseStatus,
    PromiseSource,
    PromiseEventType
)


class PaymentPromiseRepository:
    def __init__(self, db: Session):
        self.db = db

    def _attach_events(self, promise: Optional[PaymentPromise]) -> Optional[PaymentPromise]:
        if promise:
            promise.events = self.db.query(PaymentPromiseEvent).filter(
                PaymentPromiseEvent.payment_promise_id == promise.id
            ).order_by(PaymentPromiseEvent.created_at.asc()).all()
        return promise

    def get_by_id(self, promise_id: UUID, merchant_id: UUID) -> Optional[PaymentPromise]:
        promise = self.db.query(PaymentPromise).filter(
            PaymentPromise.id == promise_id,
            PaymentPromise.merchant_id == merchant_id
        ).first()
        return self._attach_events(promise)

    def list_by_merchant(
        self,
        merchant_id: UUID,
        status: Optional[PromiseStatus] = None,
        skip: int = 0,
        limit: int = 50
    ) -> List[PaymentPromise]:
        query = self.db.query(PaymentPromise).filter(PaymentPromise.merchant_id == merchant_id)
        if status:
            query = query.filter(PaymentPromise.status == status)
        promises = query.order_by(PaymentPromise.due_at.asc()).offset(skip).limit(limit).all()
        for p in promises:
            self._attach_events(p)
        return promises

    def create(
        self,
        merchant_id: UUID,
        description: str,
        promised_amount: Decimal,
        due_at: datetime,
        counterparty_id: Optional[UUID] = None,
        currency: str = "INR",
        promise_direction: PromiseDirection = PromiseDirection.EXPECTED_INCOMING,
        source: PromiseSource = PromiseSource.MERCHANT_DECLARED,
        source_reference: Optional[str] = None
    ) -> PaymentPromise:
        promise = PaymentPromise(
            merchant_id=merchant_id,
            counterparty_id=counterparty_id,
            description=description,
            promised_amount=promised_amount,
            currency=currency,
            promise_direction=promise_direction,
            due_at=due_at,
            status=PromiseStatus.OPEN,
            source=source,
            source_reference=source_reference
        )
        self.db.add(promise)
        self.db.commit()
        self.db.refresh(promise)

        # Log CREATED event
        self.record_event(
            merchant_id=merchant_id,
            payment_promise_id=promise.id,
            event_type=PromiseEventType.CREATED,
            new_snapshot=self._snapshot(promise)
        )
        return self._attach_events(promise)

    def record_event(
        self,
        merchant_id: UUID,
        payment_promise_id: UUID,
        event_type: PromiseEventType,
        previous_snapshot: Optional[Dict[str, Any]] = None,
        new_snapshot: Optional[Dict[str, Any]] = None
    ) -> PaymentPromiseEvent:
        event = PaymentPromiseEvent(
            merchant_id=merchant_id,
            payment_promise_id=payment_promise_id,
            event_type=event_type,
            previous_snapshot=previous_snapshot or {},
            new_snapshot=new_snapshot or {}
        )
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event

    def fulfill(self, promise: PaymentPromise, fulfillment_reference: Optional[str] = None) -> PaymentPromise:
        prev_snap = self._snapshot(promise)
        promise.status = PromiseStatus.FULFILLED
        promise.fulfilled_at = datetime.now(timezone.utc)
        if fulfillment_reference:
            promise.source_reference = fulfillment_reference
        self.db.commit()
        self.db.refresh(promise)

        self.record_event(
            merchant_id=promise.merchant_id,
            payment_promise_id=promise.id,
            event_type=PromiseEventType.FULFILLED,
            previous_snapshot=prev_snap,
            new_snapshot=self._snapshot(promise)
        )
        return self._attach_events(promise)

    def cancel(self, promise: PaymentPromise) -> PaymentPromise:
        prev_snap = self._snapshot(promise)
        promise.status = PromiseStatus.CANCELLED
        self.db.commit()
        self.db.refresh(promise)

        self.record_event(
            merchant_id=promise.merchant_id,
            payment_promise_id=promise.id,
            event_type=PromiseEventType.CANCELLED,
            previous_snapshot=prev_snap,
            new_snapshot=self._snapshot(promise)
        )
        return self._attach_events(promise)

    def _snapshot(self, promise: PaymentPromise) -> Dict[str, Any]:
        return {
            "id": str(promise.id),
            "merchant_id": str(promise.merchant_id),
            "counterparty_id": str(promise.counterparty_id) if promise.counterparty_id else None,
            "description": promise.description,
            "promised_amount": str(promise.promised_amount),
            "due_at": promise.due_at.isoformat() if promise.due_at else None,
            "status": promise.status.value,
            "fulfilled_at": promise.fulfilled_at.isoformat() if promise.fulfilled_at else None,
        }
