from uuid import UUID
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.communication_action import CommunicationAction, ActionType, CommunicationChannel, ActionStatus
from app.models.communication_action_event import CommunicationAuditEvent


class CommunicationActionRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, merchant_id: UUID, action_id: UUID) -> Optional[CommunicationAction]:
        m_uuid = UUID(str(merchant_id)) if not isinstance(merchant_id, UUID) else merchant_id
        a_uuid = UUID(str(action_id)) if not isinstance(action_id, UUID) else action_id
        return self.db.query(CommunicationAction).filter(
            CommunicationAction.id == a_uuid,
            CommunicationAction.merchant_id == m_uuid
        ).first()

    def get_by_idempotency_key(self, merchant_id: UUID, idempotency_key: str) -> Optional[CommunicationAction]:
        m_uuid = UUID(str(merchant_id)) if not isinstance(merchant_id, UUID) else merchant_id
        return self.db.query(CommunicationAction).filter(
            CommunicationAction.merchant_id == m_uuid,
            CommunicationAction.idempotency_key == idempotency_key
        ).first()

    def get_by_promise_id(self, merchant_id: UUID, promise_id: UUID) -> Optional[CommunicationAction]:
        m_uuid = UUID(str(merchant_id)) if not isinstance(merchant_id, UUID) else merchant_id
        p_uuid = UUID(str(promise_id)) if not isinstance(promise_id, UUID) else promise_id
        return self.db.query(CommunicationAction).filter(
            CommunicationAction.merchant_id == m_uuid,
            CommunicationAction.related_entity_id == p_uuid
        ).first()

    def list_by_merchant(
        self,
        merchant_id: UUID,
        status: Optional[ActionStatus] = None,
        skip: int = 0,
        limit: int = 50
    ) -> List[CommunicationAction]:
        m_uuid = UUID(str(merchant_id)) if not isinstance(merchant_id, UUID) else merchant_id
        query = self.db.query(CommunicationAction).filter(CommunicationAction.merchant_id == m_uuid)
        if status:
            query = query.filter(CommunicationAction.status == status)
        return query.order_by(CommunicationAction.created_at.desc()).offset(skip).limit(limit).all()

    def create_action(
        self,
        merchant_id: UUID,
        action_type: ActionType,
        channel: CommunicationChannel,
        related_entity_type: str,
        related_entity_id: Optional[UUID],
        counterparty_id: Optional[UUID],
        recipient_identifier: Optional[str],
        draft_content: str,
        idempotency_key: Optional[str] = None,
        metadata_info: Optional[Dict[str, Any]] = None
    ) -> tuple[CommunicationAction, bool]:
        m_uuid = UUID(str(merchant_id)) if not isinstance(merchant_id, UUID) else merchant_id
        c_uuid = UUID(str(counterparty_id)) if counterparty_id and not isinstance(counterparty_id, UUID) else counterparty_id
        r_uuid = UUID(str(related_entity_id)) if related_entity_id and not isinstance(related_entity_id, UUID) else related_entity_id

        if idempotency_key:
            existing = self.get_by_idempotency_key(m_uuid, idempotency_key)
            if existing:
                return existing, False

        action = CommunicationAction(
            merchant_id=m_uuid,
            action_type=action_type,
            channel=channel,
            related_entity_type=related_entity_type,
            related_entity_id=r_uuid,
            counterparty_id=c_uuid,
            recipient_identifier=recipient_identifier,
            draft_content=draft_content,
            final_content=draft_content,
            status=ActionStatus.DRAFT,
            idempotency_key=idempotency_key,
            metadata_info=metadata_info or {}
        )
        self.db.add(action)
        self.db.commit()
        self.db.refresh(action)

        self.record_audit_event(
            action_id=action.id,
            event_type="ACTION_CREATED",
            previous_status=None,
            new_status=action.status.value,
            actor_type="MERCHANT"
        )

        return action, True

    def record_audit_event(
        self,
        action_id: UUID,
        event_type: str,
        previous_status: Optional[str],
        new_status: str,
        actor_type: str = "MERCHANT",
        metadata_info: Optional[Dict[str, Any]] = None
    ) -> CommunicationAuditEvent:
        a_uuid = UUID(str(action_id)) if not isinstance(action_id, UUID) else action_id
        audit = CommunicationAuditEvent(
            communication_action_id=a_uuid,
            event_type=event_type,
            previous_status=previous_status,
            new_status=new_status,
            actor_type=actor_type,
            metadata_info=metadata_info or {},
            occurred_at=datetime.now(timezone.utc)
        )
        self.db.add(audit)
        self.db.commit()
        self.db.refresh(audit)
        return audit

    def list_audit_events(self, action_id: UUID) -> List[CommunicationAuditEvent]:
        a_uuid = UUID(str(action_id)) if not isinstance(action_id, UUID) else action_id
        return self.db.query(CommunicationAuditEvent).filter(
            CommunicationAuditEvent.communication_action_id == a_uuid
        ).order_by(CommunicationAuditEvent.occurred_at.asc()).all()
