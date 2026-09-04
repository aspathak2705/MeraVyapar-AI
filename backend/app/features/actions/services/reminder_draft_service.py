from typing import Optional, Dict, Any, Tuple
from sqlalchemy.orm import Session
import uuid

from app.models.payment_promise import PaymentPromise
from app.models.communication_action import CommunicationAction, ActionType, CommunicationChannel, ActionStatus
from app.repositories.communication_action_repository import CommunicationActionRepository


class ReminderDraftService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CommunicationActionRepository(db)

    def draft_payment_reminder(
        self,
        merchant_id: str,
        promise_id: str,
        channel: CommunicationChannel = CommunicationChannel.WHATSAPP
    ) -> Tuple[CommunicationAction, bool]:
        promise_uuid = uuid.UUID(promise_id) if isinstance(promise_id, str) else promise_id
        merchant_uuid = uuid.UUID(merchant_id) if isinstance(merchant_id, str) else merchant_id

        promise = self.db.query(PaymentPromise).filter(
            PaymentPromise.id == promise_uuid,
            PaymentPromise.merchant_id == merchant_uuid
        ).first()

        if not promise:
            raise ValueError(f"Payment promise {promise_id} not found for merchant {merchant_id}")

        existing = self.repo.get_by_promise_id(merchant_uuid, promise_uuid)
        if existing and existing.status in [
            ActionStatus.DRAFT, ActionStatus.READY_FOR_REVIEW,
            ActionStatus.CONFIRMED_BY_MERCHANT, ActionStatus.DISPATCH_REQUESTED
        ]:
            return existing, False

        amount_str = f"₹{promise.promised_amount:,.2f}"
        due_str = promise.due_at.strftime("%Y-%m-%d") if promise.due_at else "due date"
        desc_str = f" ({promise.description})" if promise.description else ""

        draft_content = (
            f"Dear Counterparty, this is a reminder regarding payment of {amount_str}"
            f"{desc_str} due on {due_str}. Please confirm once paid. Thank you!"
        )

        idempotency_key = f"draft:{merchant_id}:{promise_id}"

        action, created = self.repo.create_action(
            merchant_id=merchant_uuid,
            action_type=ActionType.PAYMENT_REMINDER,
            channel=channel,
            related_entity_type="payment_promise",
            related_entity_id=promise_uuid,
            counterparty_id=promise.counterparty_id,
            recipient_identifier=None,
            draft_content=draft_content,
            idempotency_key=idempotency_key
        )

        return action, created
