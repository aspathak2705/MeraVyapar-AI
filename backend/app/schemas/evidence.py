from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from typing import Optional, Dict, Any
from app.models.financial_evidence import EvidenceType, EvidenceSource, EvidenceStrength, ProcessingStatus
from app.models.transaction_candidate import TransactionType, PaymentMode


class ManualEvidenceCreate(BaseModel):
    amount: str = Field(..., description="Monetary amount e.g. 5000.00")
    currency: str = Field(default="INR", max_length=3)
    transaction_type: TransactionType
    description: Optional[str] = None
    counterparty_name: Optional[str] = None
    payment_mode: Optional[PaymentMode] = PaymentMode.UNKNOWN
    transaction_timestamp: Optional[datetime] = None


class TextEvidenceCreate(BaseModel):
    evidence_type: EvidenceType = EvidenceType.BANK_SMS
    raw_text: str = Field(..., min_length=1)
    metadata_info: Optional[Dict[str, Any]] = None


class EvidenceRegistrationCreate(BaseModel):
    evidence_id: UUID
    evidence_type: EvidenceType = EvidenceType.PAYMENT_SCREENSHOT
    content_type: str = Field(..., description="Allowed MIME type: image/jpeg, image/png, application/pdf")
    original_filename: str = Field(..., max_length=255)
    size_bytes: int = Field(..., gt=0, le=10 * 1024 * 1024, description="File size up to 10 MB")
    client_sha256: str = Field(..., pattern=r"^[0-9a-fA-F]{64}$", description="64-char hex SHA-256 hash")
    storage_version: int = Field(default=1)


class EvidenceExtractionSubmission(BaseModel):
    extracted_text: Optional[str] = None
    amount: Optional[str] = Field(None, description="Extracted monetary amount e.g. 2500.00")
    currency: str = Field(default="INR", max_length=3)
    transaction_type: Optional[TransactionType] = None
    counterparty_name: Optional[str] = None
    payment_mode: Optional[PaymentMode] = PaymentMode.UNKNOWN
    reference_number: Optional[str] = None
    description: Optional[str] = None
    extraction_engine: Optional[str] = Field(default="TFLiteExtractionEngine")
    confidence: Optional[float] = None
    client_sha256: str = Field(..., pattern=r"^[0-9a-fA-F]{64}$", description="Integrity check matching registered evidence")


class EvidenceResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    evidence_type: EvidenceType
    evidence_source: EvidenceSource
    evidence_strength: EvidenceStrength
    raw_text: Optional[str] = None
    metadata_info: Dict[str, Any] = Field(..., alias="metadata_info")
    storage_object_key: Optional[str] = None
    content_type: Optional[str] = None
    original_filename: Optional[str] = None
    processing_status: ProcessingStatus
    received_at: datetime
    processed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)
