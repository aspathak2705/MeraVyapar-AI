from uuid import UUID
import uuid
from typing import List, Optional

from sqlalchemy.orm import Session
from app.models.financial_evidence import (
    FinancialEvidence,
    EvidenceType,
    EvidenceSource,
    EvidenceStrength,
    ProcessingStatus
)


class EvidenceRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, evidence_id: UUID, merchant_id: UUID) -> Optional[FinancialEvidence]:
        return self.db.query(FinancialEvidence).filter(
            FinancialEvidence.id == evidence_id,
            FinancialEvidence.merchant_id == merchant_id
        ).first()

    def get_by_id_any_merchant(self, evidence_id: UUID) -> Optional[FinancialEvidence]:
        return self.db.query(FinancialEvidence).filter(
            FinancialEvidence.id == evidence_id
        ).first()

    def get_by_idempotency_key(self, merchant_id: UUID, key: str) -> Optional[FinancialEvidence]:
        return self.db.query(FinancialEvidence).filter(
            FinancialEvidence.merchant_id == merchant_id,
            FinancialEvidence.idempotency_key == key
        ).first()

    def list_by_merchant(
        self,
        merchant_id: UUID,
        skip: int = 0,
        limit: int = 50
    ) -> List[FinancialEvidence]:
        return self.db.query(FinancialEvidence).filter(
            FinancialEvidence.merchant_id == merchant_id
        ).order_by(FinancialEvidence.created_at.desc()).offset(skip).limit(limit).all()

    def create(
        self,
        merchant_id: UUID,
        evidence_type: EvidenceType,
        evidence_source: EvidenceSource,
        evidence_strength: EvidenceStrength,
        raw_text: Optional[str] = None,
        metadata_info: Optional[dict] = None,
        storage_object_key: Optional[str] = None,
        content_type: Optional[str] = None,
        original_filename: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        processing_status: ProcessingStatus = ProcessingStatus.RECEIVED,
        evidence_id: Optional[UUID] = None
    ) -> FinancialEvidence:
        evidence = FinancialEvidence(
            id=evidence_id or uuid.uuid4(),
            merchant_id=merchant_id,

            evidence_type=evidence_type,
            evidence_source=evidence_source,
            evidence_strength=evidence_strength,
            raw_text=raw_text,
            metadata_info=metadata_info or {},
            storage_object_key=storage_object_key,
            content_type=content_type,
            original_filename=original_filename,
            idempotency_key=idempotency_key,
            processing_status=processing_status
        )
        self.db.add(evidence)
        self.db.commit()
        self.db.refresh(evidence)
        return evidence

    def update_status(
        self,
        evidence: FinancialEvidence,
        status: ProcessingStatus
    ) -> FinancialEvidence:
        evidence.processing_status = status
        self.db.commit()
        self.db.refresh(evidence)
        return evidence
