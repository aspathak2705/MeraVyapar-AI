from uuid import UUID
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from fastapi import UploadFile
from sqlalchemy.orm import Session
from app.repositories.evidence_repository import EvidenceRepository
from app.repositories.idempotency_repository import IdempotencyRepository
from app.repositories.capture_setting_repository import CaptureSettingRepository
from app.services.evidence_processing_service import EvidenceProcessingService
from app.infrastructure.storage.object_storage import LocalDevObjectStorage
from app.models.financial_evidence import (
    FinancialEvidence,
    EvidenceType,
    EvidenceSource,
    EvidenceStrength,
    ProcessingStatus
)
from app.models.capture_source_setting import CaptureSourceType
from app.core.exceptions import ValidationError, InfrastructureError


class CaptureIngestionService:
    ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "application/pdf"]
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

    def __init__(self, db: Session):
        self.db = db
        self.evidence_repo = EvidenceRepository(db)
        self.idempotency_repo = IdempotencyRepository(db)
        self.setting_repo = CaptureSettingRepository(db)
        self.processor = EvidenceProcessingService(db)
        self.storage = LocalDevObjectStorage()

    def ingest_shared_text(self, merchant_id: UUID, text: str, metadata: Optional[Dict[str, Any]] = None) -> FinancialEvidence:
        if not text or not text.strip():
            raise ValidationError("Shared text payload cannot be empty")

        meta = metadata or {}
        meta["capture_method"] = "user_shared_text"

        evidence = self.evidence_repo.create(
            merchant_id=merchant_id,
            evidence_type=EvidenceType.NOTIFICATION,
            evidence_source=EvidenceSource.USER_SHARED_TEXT,
            evidence_strength=EvidenceStrength.MERCHANT_DECLARED,
            raw_text=text.strip(),
            metadata_info=meta,
            processing_status=ProcessingStatus.RECEIVED
        )
        return self.processor.process_evidence(evidence)

    def ingest_shared_file(self, merchant_id: UUID, file: UploadFile, metadata: Optional[Dict[str, Any]] = None) -> FinancialEvidence:
        if file.content_type not in self.ALLOWED_MIME_TYPES:
            raise ValidationError(f"Invalid file MIME type: {file.content_type}. Allowed: {self.ALLOWED_MIME_TYPES}")

        file.file.seek(0, 2)
        size = file.file.tell()
        file.file.seek(0)

        if size == 0:
            raise ValidationError("Empty file payload rejected")
        if size > self.MAX_FILE_SIZE:
            raise ValidationError("File size exceeds 10MB limit")

        object_key = f"merchants/{merchant_id}/shares/{file.filename}"
        self.storage.upload(file.file, object_key, file.content_type)

        meta = metadata or {}
        meta["capture_method"] = "user_shared_file"

        evidence = self.evidence_repo.create(
            merchant_id=merchant_id,
            evidence_type=EvidenceType.PAYMENT_SCREENSHOT,
            evidence_source=EvidenceSource.USER_SHARED_FILE,
            evidence_strength=EvidenceStrength.MERCHANT_DECLARED,
            metadata_info=meta,
            storage_object_key=object_key,
            content_type=file.content_type,
            original_filename=file.filename,
            processing_status=ProcessingStatus.RECEIVED
        )
        return self.processor.process_evidence(evidence)

    def ingest_notification(
        self,
        merchant_id: UUID,
        provider_identifier: str,
        title: str,
        text: str,
        posted_at: Optional[datetime] = None,
        external_event_id: Optional[str] = None
    ) -> Optional[FinancialEvidence]:
        setting = self.setting_repo.get_setting(
            merchant_id, CaptureSourceType.NOTIFICATION_CAPTURE, provider_identifier
        )
        if setting and not setting.enabled:
            return None

        if external_event_id:
            dedup_key = f"notif_{provider_identifier}_{external_event_id}"
            if self.idempotency_repo.get(merchant_id, dedup_key):
                return None

        meta = {
            "provider_identifier": provider_identifier,
            "title": title,
            "posted_at": posted_at.isoformat() if posted_at else None,
            "external_event_id": external_event_id,
            "capture_method": "notification_listener"
        }

        full_raw_text = f"{title}: {text}" if title else text

        evidence = self.evidence_repo.create(
            merchant_id=merchant_id,
            evidence_type=EvidenceType.NOTIFICATION,
            evidence_source=EvidenceSource.NOTIFICATION_CAPTURE,
            evidence_strength=EvidenceStrength.STRONG,
            raw_text=full_raw_text,
            metadata_info=meta,
            processing_status=ProcessingStatus.RECEIVED
        )

        if external_event_id:
            dedup_key = f"notif_{provider_identifier}_{external_event_id}"
            self.idempotency_repo.create(merchant_id, dedup_key, "notification_capture", evidence.id)

        return self.processor.process_evidence(evidence)

    def ingest_sms(
        self,
        merchant_id: UUID,
        sender: str,
        body: str,
        received_at: Optional[datetime] = None,
        external_event_id: Optional[str] = None
    ) -> Optional[FinancialEvidence]:
        setting = self.setting_repo.get_setting(
            merchant_id, CaptureSourceType.SMS_CAPTURE, sender
        )
        if setting and not setting.enabled:
            return None

        if external_event_id:
            dedup_key = f"sms_{sender}_{external_event_id}"
            if self.idempotency_repo.get(merchant_id, dedup_key):
                return None

        meta = {
            "sender": sender,
            "received_at": received_at.isoformat() if received_at else None,
            "external_event_id": external_event_id,
            "capture_method": "sms_receiver"
        }

        evidence = self.evidence_repo.create(
            merchant_id=merchant_id,
            evidence_type=EvidenceType.BANK_SMS,
            evidence_source=EvidenceSource.SMS_CAPTURE,
            evidence_strength=EvidenceStrength.STRONG,
            raw_text=body,
            metadata_info=meta,
            processing_status=ProcessingStatus.RECEIVED
        )

        if external_event_id:
            dedup_key = f"sms_{sender}_{external_event_id}"
            self.idempotency_repo.create(merchant_id, dedup_key, "sms_capture", evidence.id)

        return self.processor.process_evidence(evidence)
