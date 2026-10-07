from uuid import UUID
from typing import List, Optional
from fastapi import APIRouter, Depends, Header, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.services.evidence_service import EvidenceService
from app.services.evidence_processing_service import EvidenceProcessingService
from app.schemas.evidence import (
    ManualEvidenceCreate,
    TextEvidenceCreate,
    EvidenceRegistrationCreate,
    EvidenceExtractionSubmission,
    EvidenceResponse
)
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.models.financial_evidence import EvidenceType

router = APIRouter()


@router.post("/evidence/register", response_model=APIResponse, status_code=status.HTTP_201_CREATED)
def register_mobile_evidence(
    payload: EvidenceRegistrationCreate,
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    evidence = service.register_mobile_evidence(
        merchant_id=merchant.id,
        payload=payload,
        idempotency_key=x_idempotency_key
    )

    evidence_data = EvidenceResponse.model_validate(evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Mobile app-private evidence metadata registered successfully",
        data=evidence_data
    )


@router.post("/evidence/{evidence_id}/extraction", response_model=APIResponse, status_code=status.HTTP_200_OK)
def submit_evidence_extraction(
    evidence_id: UUID,
    payload: EvidenceExtractionSubmission,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    evidence = service.get_evidence(evidence_id, merchant.id)

    processor = EvidenceProcessingService(db)
    processed_evidence = processor.process_extraction_submission(evidence, payload)

    evidence_data = EvidenceResponse.model_validate(processed_evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="On-device extraction submitted and processed into financial pipeline",
        data=evidence_data
    )



@router.post("/evidence/manual", response_model=APIResponse, status_code=status.HTTP_201_CREATED)
def submit_manual_evidence(
    payload: ManualEvidenceCreate,
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    evidence = service.create_manual_evidence(merchant.id, payload, idempotency_key=x_idempotency_key)

    # Process through pipeline
    processor = EvidenceProcessingService(db)
    processed_evidence = processor.process_evidence(evidence)

    evidence_data = EvidenceResponse.model_validate(processed_evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Manual financial evidence submitted and processed",
        data=evidence_data
    )


@router.post("/evidence/text", response_model=APIResponse, status_code=status.HTTP_201_CREATED)
def submit_text_evidence(
    payload: TextEvidenceCreate,
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    evidence = service.create_text_evidence(merchant.id, payload, idempotency_key=x_idempotency_key)

    # Process through pipeline
    processor = EvidenceProcessingService(db)
    processed_evidence = processor.process_evidence(evidence)

    evidence_data = EvidenceResponse.model_validate(processed_evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Text financial evidence submitted",
        data=evidence_data
    )


@router.post(
    "/evidence/file",
    response_model=APIResponse,
    status_code=status.HTTP_201_CREATED,
    deprecated=True,
    description="[DEPRECATED] Transitional legacy multipart evidence upload. New clients must use on-device storage with /evidence/register and /evidence/{id}/extraction."
)
async def upload_file_evidence(
    file: UploadFile = File(...),
    evidence_type: EvidenceType = Form(EvidenceType.PAYMENT_SCREENSHOT),
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    evidence = service.create_file_evidence(
        merchant_id=merchant.id,
        file_obj=file.file,
        filename=file.filename or "uploaded_evidence",
        content_type=file.content_type or "application/octet-stream",
        evidence_type=evidence_type,
        idempotency_key=x_idempotency_key
    )

    processor = EvidenceProcessingService(db)
    processed_evidence = processor.process_evidence(evidence)

    evidence_data = EvidenceResponse.model_validate(processed_evidence).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="File evidence uploaded successfully",
        data=evidence_data
    )


@router.get("/evidence", response_model=APIResponse)
def list_merchant_evidence(
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    records = service.list_evidence(merchant.id, skip=skip, limit=limit)
    records_data = [EvidenceResponse.model_validate(r).model_dump(mode="json") for r in records]
    return APIResponse(
        success=True,
        message="Financial evidence records retrieved",
        data=records_data
    )


@router.get("/evidence/{evidence_id}", response_model=APIResponse)
def get_merchant_evidence_by_id(
    evidence_id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = EvidenceService(db)
    record = service.get_evidence(evidence_id, merchant.id)
    record_data = EvidenceResponse.model_validate(record).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Financial evidence record retrieved",
        data=record_data
    )
