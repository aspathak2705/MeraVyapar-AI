from fastapi import APIRouter, Depends, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.features.capture.services.capture_ingestion_service import CaptureIngestionService
from app.repositories.capture_setting_repository import CaptureSettingRepository
from app.schemas.capture import (
    SharedTextCaptureRequest,
    NotificationCaptureRequest,
    SmsCaptureRequest,
    CaptureSourceSettingResponse,
    CaptureSourceSettingUpdateRequest
)
from app.schemas.evidence import EvidenceResponse
from app.schemas.common import APIResponse
from app.models.merchant import Merchant

router = APIRouter()


@router.post("/capture/shared-text", response_model=APIResponse)
def capture_shared_text(
    payload: SharedTextCaptureRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = CaptureIngestionService(db)
    evidence = service.ingest_shared_text(merchant.id, payload.text, payload.metadata)
    evidence_data = EvidenceResponse.model_validate(evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Shared text evidence captured",
        data=evidence_data
    )


@router.post("/capture/shared-file", response_model=APIResponse)
def capture_shared_file(
    file: UploadFile = File(...),
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = CaptureIngestionService(db)
    evidence = service.ingest_shared_file(merchant.id, file)
    evidence_data = EvidenceResponse.model_validate(evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Shared file evidence captured",
        data=evidence_data
    )


@router.post("/capture/notification", response_model=APIResponse)
def capture_notification(
    payload: NotificationCaptureRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = CaptureIngestionService(db)
    evidence = service.ingest_notification(
        merchant.id,
        payload.provider_identifier,
        payload.title or "",
        payload.text,
        payload.posted_at,
        payload.external_event_id
    )
    if not evidence:
        return APIResponse(
            success=True,
            message="Notification ignored or disabled by provider setting",
            data=None
        )

    evidence_data = EvidenceResponse.model_validate(evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Notification evidence captured",
        data=evidence_data
    )


@router.post("/capture/sms", response_model=APIResponse)
def capture_sms(
    payload: SmsCaptureRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = CaptureIngestionService(db)
    evidence = service.ingest_sms(
        merchant.id,
        payload.sender,
        payload.body,
        payload.received_at,
        payload.external_event_id
    )
    if not evidence:
        return APIResponse(
            success=True,
            message="SMS ignored or disabled by provider setting",
            data=None
        )

    evidence_data = EvidenceResponse.model_validate(evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="SMS evidence captured",
        data=evidence_data
    )


@router.get("/capture/settings", response_model=APIResponse)
def list_capture_settings(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CaptureSettingRepository(db)
    settings = repo.list_settings(merchant.id)
    settings_data = [CaptureSourceSettingResponse.model_validate(s).model_dump(mode="json") for s in settings]
    return APIResponse(
        success=True,
        message="Capture source settings retrieved",
        data=settings_data
    )


@router.put("/capture/settings", response_model=APIResponse)
def update_capture_setting(
    payload: CaptureSourceSettingUpdateRequest,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CaptureSettingRepository(db)
    setting = repo.upsert_setting(
        merchant.id,
        payload.source_type,
        payload.provider_identifier,
        payload.enabled
    )
    setting_data = CaptureSourceSettingResponse.model_validate(setting).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Capture source setting updated",
        data=setting_data
    )
