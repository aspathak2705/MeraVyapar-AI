from uuid import UUID
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.financial_event import FinancialEvent, EventType, EventSeverity, EventStatus


class FinancialEventRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, event_id: UUID, merchant_id: UUID) -> Optional[FinancialEvent]:
        return self.db.query(FinancialEvent).filter(
            FinancialEvent.id == event_id,
            FinancialEvent.merchant_id == merchant_id
        ).first()

    def get_by_deduplication_key(self, merchant_id: UUID, dedup_key: str) -> Optional[FinancialEvent]:
        return self.db.query(FinancialEvent).filter(
            FinancialEvent.merchant_id == merchant_id,
            FinancialEvent.deduplication_key == dedup_key
        ).first()

    def list_by_merchant(
        self,
        merchant_id: UUID,
        status: Optional[EventStatus] = None,
        event_type: Optional[EventType] = None,
        skip: int = 0,
        limit: int = 50
    ) -> List[FinancialEvent]:
        query = self.db.query(FinancialEvent).filter(FinancialEvent.merchant_id == merchant_id)
        if status:
            query = query.filter(FinancialEvent.status == status)
        if event_type:
            query = query.filter(FinancialEvent.event_type == event_type)
        return query.order_by(FinancialEvent.occurred_at.desc()).offset(skip).limit(limit).all()

    def create_or_update_event(
        self,
        merchant_id: UUID,
        event_type: EventType,
        severity: EventSeverity,
        title: str,
        summary: str,
        source_entity_type: str,
        source_entity_id: Optional[UUID] = None,
        deduplication_key: Optional[str] = None,
        occurred_at: Optional[datetime] = None,
        metadata_info: Optional[Dict[str, Any]] = None
    ) -> tuple[FinancialEvent, bool]:
        now = datetime.now(timezone.utc)
        if deduplication_key:
            existing = self.get_by_deduplication_key(merchant_id, deduplication_key)
            if existing:
                if existing.status in (EventStatus.RESOLVED, EventStatus.DISMISSED):
                    existing.status = EventStatus.ACTIVE
                existing.severity = severity
                existing.title = title
                existing.summary = summary
                existing.metadata_info = metadata_info or {}
                existing.updated_at = now
                self.db.commit()
                self.db.refresh(existing)
                return existing, False

        event = FinancialEvent(
            merchant_id=merchant_id,
            event_type=event_type,
            severity=severity,
            status=EventStatus.ACTIVE,
            title=title,
            summary=summary,
            source_entity_type=source_entity_type,
            source_entity_id=source_entity_id,
            deduplication_key=deduplication_key,
            occurred_at=occurred_at or now,
            detected_at=now,
            metadata_info=metadata_info or {}
        )
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event, True

    def resolve_event_by_key(self, merchant_id: UUID, dedup_key: str) -> bool:
        event = self.get_by_deduplication_key(merchant_id, dedup_key)
        if event and event.status == EventStatus.ACTIVE:
            event.status = EventStatus.RESOLVED
            event.updated_at = datetime.now(timezone.utc)
            self.db.commit()
            return True
        return False
