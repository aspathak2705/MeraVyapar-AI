from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import uuid

from app.models.communication_action import CommunicationAction, ActionStatus
from app.repositories.communication_action_repository import CommunicationActionRepository
from app.infrastructure.communication.provider_factory import CommunicationProviderFactory


class ActionDispatchService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CommunicationActionRepository(db)

    def dispatch_action(
        self,
        merchant_id: str,
        action_id: str
    ) -> CommunicationAction:
        m_uuid = uuid.UUID(merchant_id) if isinstance(merchant_id, str) else merchant_id
        a_uuid = uuid.UUID(action_id) if isinstance(action_id, str) else action_id

        action = self.repo.get_by_id(m_uuid, a_uuid)
        if not action:
            raise ValueError(f"Action {action_id} not found")

        if action.status == ActionStatus.SENT:
            return action

        if action.status == ActionStatus.DISPATCH_REQUESTED:
            return action

        if action.status not in [ActionStatus.CONFIRMED_BY_MERCHANT, ActionStatus.FAILED]:
            raise ValueError(
                f"Cannot dispatch action in status {action.status.value}. "
                f"Action must be explicitly confirmed by merchant first."
            )

        prev_status = action.status.value
        action.status = ActionStatus.DISPATCH_REQUESTED
        action.updated_at = datetime.now(timezone.utc)

        self.db.commit()

        self.repo.record_audit_event(
            action_id=action.id,
            event_type="DISPATCH_REQUESTED",
            previous_status=prev_status,
            new_status=action.status.value,
            actor_type="SYSTEM"
        )

        message_body = action.final_content or action.draft_content

        provider = CommunicationProviderFactory.get_provider(action.channel)
        recipient_dict = {"recipient_identifier": action.recipient_identifier}
        res = provider.send_message(
            recipient_info=recipient_dict,
            content=message_body,
            idempotency_key=action.idempotency_key or ""
        )

        if res["status"] == "SENT":
            action.status = ActionStatus.SENT
            action.provider_reference = res.get("provider_message_id")
            action.provider_name = action.channel.value
            action.executed_at = datetime.now(timezone.utc)
            action.updated_at = datetime.now(timezone.utc)
            self.db.commit()
            self.db.refresh(action)

            self.repo.record_audit_event(
                action_id=action.id,
                event_type="ACTION_SENT",
                previous_status=ActionStatus.DISPATCH_REQUESTED.value,
                new_status=action.status.value,
                actor_type="SYSTEM",
                metadata_info=res.get("raw_response")
            )
        else:
            action.status = ActionStatus.FAILED
            action.failure_reason = res.get("error_message") or res.get("error_code")
            action.error_code = res.get("error_code")
            action.error_message = res.get("error_message")
            action.updated_at = datetime.now(timezone.utc)

            self.db.commit()
            self.db.refresh(action)

            self.repo.record_audit_event(
                action_id=action.id,
                event_type="ACTION_FAILED",
                previous_status=ActionStatus.DISPATCH_REQUESTED.value,
                new_status=action.status.value,
                actor_type="SYSTEM",
                metadata_info={"error_code": res.get("error_code")}
            )

        return action
