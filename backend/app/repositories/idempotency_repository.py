from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.models.idempotency_record import IdempotencyRecord


class IdempotencyRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, merchant_id: UUID, key: str) -> Optional[IdempotencyRecord]:
        return self.db.query(IdempotencyRecord).filter(
            IdempotencyRecord.merchant_id == merchant_id,
            IdempotencyRecord.idempotency_key == key
        ).first()

    def create(
        self,
        merchant_id: UUID,
        key: str,
        resource_type: str,
        resource_id: UUID,
        request_hash: Optional[str] = None
    ) -> IdempotencyRecord:
        record = IdempotencyRecord(
            merchant_id=merchant_id,
            idempotency_key=key,
            resource_type=resource_type,
            resource_id=resource_id,
            request_hash=request_hash
        )
        self.db.add(record)
        self.db.commit()
        self.db.refresh(record)
        return record
