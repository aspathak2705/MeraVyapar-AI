from uuid import UUID
from datetime import datetime, timedelta, timezone
from typing import List
from sqlalchemy.orm import Session
from app.repositories.financial_event_repository import FinancialEventRepository
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.models.payment_promise import PromiseStatus, PromiseDirection
from app.models.financial_event import EventType, EventSeverity, EventStatus
from app.schemas.financial_event import FinancialEventEvaluationResponse


class FinancialEventEvaluationService:
    DEFAULT_DUE_SOON_DAYS = 3

    def __init__(self, db: Session):
        self.db = db
        self.event_repo = FinancialEventRepository(db)
        self.promise_repo = PaymentPromiseRepository(db)
        self.counterparty_repo = CounterpartyRepository(db)

    def evaluate_merchant_events(self, merchant_id: UUID) -> FinancialEventEvaluationResponse:
        now = datetime.now(timezone.utc)
        due_soon_threshold = now + timedelta(days=self.DEFAULT_DUE_SOON_DAYS)

        all_promises = self.promise_repo.list_by_merchant(merchant_id, skip=0, limit=200)

        evaluated_cnt = len(all_promises)
        created_cnt = 0
        updated_cnt = 0
        resolved_cnt = 0

        # Track open promise counts per counterparty
        cp_open_promises = {}

        for p in all_promises:
            dedup_overdue_key = f"promise_overdue_{p.id}"
            dedup_duesoon_key = f"promise_duesoon_{p.id}"

            cp_name = "Counterparty"
            if p.counterparty_id:
                cp = self.counterparty_repo.get_by_id(p.counterparty_id, merchant_id)
                if cp:
                    cp_name = cp.display_name

            if p.status in (PromiseStatus.FULFILLED, PromiseStatus.CANCELLED):
                # Resolve active promise events if promise fulfilled/cancelled
                if self.event_repo.resolve_event_by_key(merchant_id, dedup_overdue_key):
                    resolved_cnt += 1
                if self.event_repo.resolve_event_by_key(merchant_id, dedup_duesoon_key):
                    resolved_cnt += 1
                continue

            if p.status == PromiseStatus.OPEN:
                if p.counterparty_id:
                    cp_open_promises[p.counterparty_id] = cp_open_promises.get(p.counterparty_id, 0) + 1

                # Normalize naive due_at timestamps if needed
                due_at = p.due_at
                if due_at and due_at.tzinfo is None:
                    due_at = due_at.replace(tzinfo=timezone.utc)

                if due_at < now:
                    # PAYMENT_PROMISE_OVERDUE
                    # Resolve due_soon if previously active
                    self.event_repo.resolve_event_by_key(merchant_id, dedup_duesoon_key)

                    _, created = self.event_repo.create_or_update_event(
                        merchant_id=merchant_id,
                        event_type=EventType.PAYMENT_PROMISE_OVERDUE,
                        severity=EventSeverity.ATTENTION,
                        title=f"Payment Overdue: {cp_name}",
                        summary=f"Expected ₹{p.promised_amount} was due on {due_at.strftime('%d %b %Y')}",
                        source_entity_type="payment_promise",
                        source_entity_id=p.id,
                        deduplication_key=dedup_overdue_key,
                        occurred_at=due_at,
                        metadata_info={
                            "reason_code": "PROMISE_PAST_DUE_DATE",
                            "payment_promise_id": str(p.id),
                            "promised_amount": str(p.promised_amount),
                            "due_at": due_at.isoformat()
                        }
                    )
                    if created:
                        created_cnt += 1
                    else:
                        updated_cnt += 1

                elif due_at <= due_soon_threshold:
                    # PAYMENT_PROMISE_DUE_SOON
                    _, created = self.event_repo.create_or_update_event(
                        merchant_id=merchant_id,
                        event_type=EventType.PAYMENT_PROMISE_DUE_SOON,
                        severity=EventSeverity.INFO,
                        title=f"Payment Expected Soon: {cp_name}",
                        summary=f"Expected ₹{p.promised_amount} due on {due_at.strftime('%d %b %Y')}",
                        source_entity_type="payment_promise",
                        source_entity_id=p.id,
                        deduplication_key=dedup_duesoon_key,
                        occurred_at=due_at,
                        metadata_info={
                            "reason_code": "PROMISE_DUE_WITHIN_WINDOW",
                            "payment_promise_id": str(p.id),
                            "promised_amount": str(p.promised_amount),
                            "due_at": due_at.isoformat()
                        }
                    )
                    if created:
                        created_cnt += 1
                    else:
                        updated_cnt += 1

        # Evaluate MULTIPLE_OPEN_PROMISES summary events
        for cp_id, count in cp_open_promises.items():
            if count >= 2:
                dedup_multi_key = f"multi_promises_cp_{cp_id}"
                cp = self.counterparty_repo.get_by_id(cp_id, merchant_id)
                cp_name = cp.display_name if cp else "Counterparty"

                _, created = self.event_repo.create_or_update_event(
                    merchant_id=merchant_id,
                    event_type=EventType.MULTIPLE_OPEN_PROMISES,
                    severity=EventSeverity.ATTENTION,
                    title=f"Multiple Open Promises: {cp_name}",
                    summary=f"{cp_name} has {count} open payment promises",
                    source_entity_type="financial_counterparty",
                    source_entity_id=cp_id,
                    deduplication_key=dedup_multi_key,
                    metadata_info={
                        "reason_code": "COUNTERPARTY_MULTIPLE_OPEN_PROMISES",
                        "open_promise_count": count
                    }
                )
                if created:
                    created_cnt += 1

        return FinancialEventEvaluationResponse(
            events_evaluated=evaluated_cnt,
            events_created=created_cnt,
            events_updated=updated_cnt,
            events_resolved=resolved_cnt
        )
