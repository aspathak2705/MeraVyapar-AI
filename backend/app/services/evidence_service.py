from uuid import UUID
from typing import List, Optional, BinaryIO
from sqlalchemy.orm import Session
from app.repositories.evidence_repository import EvidenceRepository
from app.infrastructure.storage.object_storage import get_object_storage
from app.models.financial_evidence import (
    FinancialEvidence,
    EvidenceType,
    EvidenceSource,
    EvidenceStrength,
    ProcessingStatus
)
from app.schemas.evidence import ManualEvidenceCreate, TextEvidenceCreate
from app.core.exceptions import NotFoundError, ValidationError


class EvidenceService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = EvidenceRepository(db)
        self.storage = get_object_storage()

    def get_evidence(self, evidence_id: UUID, merchant_id: UUID) -> FinancialEvidence:
        evidence = self.repo.get_by_id(evidence_id, merchant_id)
        if not evidence:
            raise NotFoundError("Financial evidence record not found")
        return evidence

    def list_evidence(self, merchant_id: UUID, skip: int = 0, limit: int = 50) -> List[FinancialEvidence]:
        return self.repo.list_by_merchant(merchant_id, skip=skip, limit=limit)

    def create_manual_evidence(
        self,
        merchant_id: UUID,
        payload: ManualEvidenceCreate,
        idempotency_key: Optional[str] = None
    ) -> FinancialEvidence:
        if idempotency_key:
            existing = self.repo.get_by_idempotency_key(merchant_id, idempotency_key)
            if existing:
                return existing

        meta = {
            "amount": payload.amount,
            "currency": payload.currency,
            "transaction_type": payload.transaction_type.value,
            "counterparty_name": payload.counterparty_name,
            "payment_mode": payload.payment_mode.value if payload.payment_mode else "UNKNOWN",
            "transaction_timestamp": payload.transaction_timestamp.isoformat() if payload.transaction_timestamp else None,
            "submission_method": "manual"
        }

        return self.repo.create(
            merchant_id=merchant_id,
            evidence_type=EvidenceType.MANUAL_ENTRY,
            evidence_source=EvidenceSource.MERCHANT_MANUAL,
            evidence_strength=EvidenceStrength.MERCHANT_DECLARED,
            raw_text=payload.description,
            metadata_info=meta,
            idempotency_key=idempotency_key,
            processing_status=ProcessingStatus.RECEIVED
        )

    def create_text_evidence(
        self,
        merchant_id: UUID,
        payload: TextEvidenceCreate,
        idempotency_key: Optional[str] = None
    ) -> FinancialEvidence:
        if idempotency_key:
            existing = self.repo.get_by_idempotency_key(merchant_id, idempotency_key)
            if existing:
                return existing

        meta = payload.metadata_info or {}
        meta["submission_method"] = "text_api"

        return self.repo.create(
            merchant_id=merchant_id,
            evidence_type=payload.evidence_type,
            evidence_source=EvidenceSource.MERCHANT_MANUAL,
            evidence_strength=EvidenceStrength.AMBIGUOUS,
            raw_text=payload.raw_text,
            metadata_info=meta,
            idempotency_key=idempotency_key,
            processing_status=ProcessingStatus.RECEIVED
        )

    def create_file_evidence(
        self,
        merchant_id: UUID,
        file_obj: BinaryIO,
        filename: str,
        content_type: str,
        evidence_type: EvidenceType = EvidenceType.PAYMENT_SCREENSHOT,
        idempotency_key: Optional[str] = None
    ) -> FinancialEvidence:
        # Validate allowed content types and header magic bytes
        from app.infrastructure.storage.validation import validate_file_signature_and_hash
        from app.infrastructure.storage.base import StorageValidationError

        try:
            sha256_hash, file_size = validate_file_signature_and_hash(file_obj, content_type)
        except StorageValidationError as val_err:
            raise ValidationError(str(val_err))

        if idempotency_key:
            existing = self.repo.get_by_idempotency_key(merchant_id, idempotency_key)
            if existing:
                return existing

        evidence_id = uuid.uuid4()
        # Whitelist extension extraction cleanly
        raw_ext = os.path.splitext(filename)[1].lower() if filename and "." in filename else ""
        ext = raw_ext if raw_ext in [".jpg", ".jpeg", ".png", ".pdf"] else ""
        object_key = f"merchants/{merchant_id}/evidence/{evidence_id}{ext}"

        stored_meta = self.storage.upload(file_obj, object_key, content_type, sha256_hash=sha256_hash)
        stored_key = stored_meta.object_key

        meta = {
            "submission_method": "file_upload",
            "original_filename": filename,
            "content_type": content_type,
            "size_bytes": file_size,
            "sha256": sha256_hash
        }

        try:
            return self.repo.create(
                evidence_id=evidence_id,
                merchant_id=merchant_id,
                evidence_type=evidence_type,
                evidence_source=EvidenceSource.UPLOAD,
                evidence_strength=EvidenceStrength.STRONG,
                metadata_info=meta,
                storage_object_key=stored_key,
                content_type=content_type,
                original_filename=filename,
                idempotency_key=idempotency_key,
                processing_status=ProcessingStatus.RECEIVED
            )

        except Exception as e:
            # Compensating action: attempt to delete uploaded object to avoid orphan files
            try:
                self.storage.delete(stored_key)
            except Exception as cleanup_err:
                from app.core.logging import logger
                logger.warning(f"Failed compensating storage cleanup for {stored_key}: {cleanup_err}")
            raise e


