from uuid import UUID
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import List
from sqlalchemy.orm import Session
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.models.payment_promise import PromiseDirection, PromiseStatus
from app.schemas.receivable import PrioritizedReceivableResponse


class ReceivablesPrioritizationService:
    SIGNIFICANT_RECEIVABLE_THRESHOLD = Decimal("10000.00")

    def __init__(self, db: Session):
        self.db = db
        self.promise_repo = PaymentPromiseRepository(db)
        self.cp_repo = CounterpartyRepository(db)

    def get_prioritized_receivables(self, merchant_id: UUID) -> List[PrioritizedReceivableResponse]:
        now = datetime.now(timezone.utc)
        due_soon_threshold = now + timedelta(days=3)

        promises = self.promise_repo.list_by_merchant(merchant_id, skip=0, limit=200)

        # Receivables derived ONLY from EXPECTED_INCOMING payment promises
        incoming_promises = [
            p for p in promises
            if p.promise_direction == PromiseDirection.EXPECTED_INCOMING and p.status == PromiseStatus.OPEN
        ]

        receivables: List[PrioritizedReceivableResponse] = []

        for p in incoming_promises:
            cp_name = None
            if p.counterparty_id:
                cp = self.cp_repo.get_by_id(p.counterparty_id, merchant_id)
                if cp:
                    cp_name = cp.display_name

            due_at = p.due_at
            if due_at and due_at.tzinfo is None:
                due_at = due_at.replace(tzinfo=timezone.utc)

            reason_codes = []
            if due_at < now:
                state = "OVERDUE"
                priority = "HIGH"
                reason_codes.append("PROMISE_PAST_DUE_DATE")
            elif due_at <= due_soon_threshold:
                state = "DUE_SOON"
                reason_codes.append("PROMISE_DUE_WITHIN_WINDOW")
                if p.promised_amount >= self.SIGNIFICANT_RECEIVABLE_THRESHOLD:
                    priority = "HIGH"
                    reason_codes.append("SIGNIFICANT_RECEIVABLE_AMOUNT")
                else:
                    priority = "MEDIUM"
            else:
                state = "PENDING"
                priority = "LOW"
                reason_codes.append("FUTURE_DUE_DATE")

            receivables.append(
                PrioritizedReceivableResponse(
                    receivable_id=str(p.id),
                    counterparty_id=p.counterparty_id,
                    counterparty_name=cp_name,
                    amount=p.promised_amount,
                    currency=p.currency,
                    due_at=due_at,
                    state=state,
                    priority=priority,
                    reason_codes=reason_codes,
                    source_payment_promise_id=p.id
                )
            )

        # Sort receivables: HIGH first, then MEDIUM, then LOW; within priority by due_at asc
        priority_order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
        receivables.sort(key=lambda r: (priority_order.get(r.priority, 3), r.due_at))

        return receivables
