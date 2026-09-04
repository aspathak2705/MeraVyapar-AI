from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import uuid

from app.models.communication_action import CommunicationAction, ActionStatus
from app.models.communication_action_event import CommunicationAuditEvent
from app.repositories.communication_action_repository import CommunicationActionRepository


class ActionWorkflowService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CommunicationActionRepository(db)

    def update_draft(
        self,
        merchant_id: str,
        action_id: str,
        final_content: str,
        recipient_info: Optional[Dict[str, Any]] = None
    ) -> CommunicationAction:
        m_uuid = uuid.UUID(merchant_id) if isinstance(merchant_id, str) else merchant_id
        a_uuid = uuid.UUID(action_id) if isinstance(action_id, str) else action_id

        action = self.repo.get_by_id(m_uuid, a_uuid)
        if not action:
            raise ValueError(f"Action {action_id} not found")

        prev_status = action.status.value
        action.final_content = final_content
        if recipient_info and "recipient_identifier" in recipient_info:
            action.recipient_identifier = recipient_info["recipient_identifier"]

        # If previously confirmed or draft, editing content or recipient resets state to READY_FOR_REVIEW
        action.status = ActionStatus.READY_FOR_REVIEW
        action.updated_at = datetime.now(timezone.utc)


        self.db.commit()
        self.db.refresh(action)

        self.repo.record_audit_event(
            action_id=action.id,
            event_type="DRAFT_UPDATED",
            previous_status=prev_status,
            new_status=action.status.value,
            actor_type="MERCHANT"
        )
        return action

    def confirm_action(
        self,
        merchant_id: str,
        action_id: str
    ) -> CommunicationAction:
        m_uuid = uuid.UUID(merchant_id) if isinstance(merchant_id, str) else merchant_id
        a_uuid = uuid.UUID(action_id) if isinstance(action_id, str) else action_id

        action = self.repo.get_by_id(m_uuid, a_uuid)
        if not action:
            raise ValueError(f"Action {action_id} not found")

        if action.status not in [ActionStatus.DRAFT, ActionStatus.READY_FOR_REVIEW]:
            raise ValueError(f"Cannot confirm action in status {action.status.value}")

        prev_status = action.status.value
        action.status = ActionStatus.CONFIRMED_BY_MERCHANT
        action.confirmed_at = datetime.now(timezone.utc)
        action.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(action)

        self.repo.record_audit_event(
            action_id=action.id,
            event_type="ACTION_CONFIRMED",
            previous_status=prev_status,
            new_status=action.status.value,
            actor_type="MERCHANT"
        )
        return action

    def cancel_action(
        self,
        merchant_id: str,
        action_id: str,
        reason: Optional[str] = None
    ) -> CommunicationAction:
        m_uuid = uuid.UUID(merchant_id) if isinstance(merchant_id, str) else merchant_id
        a_uuid = uuid.UUID(action_id) if isinstance(action_id, str) else action_id

        action = self.repo.get_by_id(m_uuid, a_uuid)
        if not action:
            raise ValueError(f"Action {action_id} not found")

        if action.status not in [ActionStatus.DRAFT, ActionStatus.READY_FOR_REVIEW, ActionStatus.CONFIRMED_BY_MERCHANT]:
            raise ValueError(f"Cannot cancel action in status {action.status.value}")

        prev_status = action.status.value
        action.status = ActionStatus.CANCELLED
        action.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(action)

        self.repo.record_audit_event(
            action_id=action.id,
            event_type="ACTION_CANCELLED",
            previous_status=prev_status,
            new_status=action.status.value,
            actor_type="MERCHANT"
        )
        return action
