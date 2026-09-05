from uuid import UUID, uuid4
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.models.merchant import Merchant
from app.features.capture.services.capture_ingestion_service import CaptureIngestionService


router = APIRouter(prefix="/demo", tags=["Demo & Simulation"])


class DemoPaymentEventRequest(BaseModel):
    event_type: str = Field(default="PAYMENT_CAPTURED", description="Type of payment event (PAYMENT_CAPTURED, PAYMENT_SETTLED)")
    amount: str = Field(..., description="Monetary amount e.g. 2500.00")
    currency: str = Field(default="INR")
    payment_method: str = Field(default="UPI", description="Payment method (UPI, BANK_TRANSFER, CARD)")
    counterparty_reference: str = Field(..., description="Counterparty e.g. Demo Customer")
    external_reference: Optional[str] = Field(default=None, description="External provider transaction reference")
    occurred_at: Optional[datetime] = Field(default=None)


@router.post("/payment-events", status_code=status.HTTP_201_CREATED)
def trigger_demo_payment_event(
    payload: DemoPaymentEventRequest,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    mode = getattr(settings, "EXTERNAL_PROVIDER_MODE", "simulation").lower()
    enable_demo = getattr(settings, "ENABLE_DEMO_ENDPOINTS", True)

    if mode != "simulation" or not enable_demo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Demo payment event simulation is disabled outside simulation mode."
        )

    ext_ref = payload.external_reference or f"demo_pay_{uuid4().hex[:12]}"
    occ_time = payload.occurred_at or datetime.now(timezone.utc)

    # Format realistic notification text for the payment provider capture pipeline
    raw_text = (
        f"Payment received: ₹{payload.amount} from {payload.counterparty_reference} "
        f"via {payload.payment_method}. Ref: {ext_ref}"
    )

    ingestion_service = CaptureIngestionService(db)
    
    # Route through existing Notification capture pipeline with explicit SIMULATED metadata
    evidence = ingestion_service.ingest_notification(
        merchant_id=current_merchant.id,
        provider_identifier="SIMULATED_RAZORPAY",
        title=f"Razorpay Demo Notification ({payload.event_type})",
        text=raw_text,
        posted_at=occ_time,
        external_event_id=ext_ref
    )

    if not evidence:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Simulated payment event already processed (idempotency key match)."
        )

    # Fetch candidates linked to this evidence
    from app.repositories.transaction_candidate_repository import TransactionCandidateRepository
    cand_repo = TransactionCandidateRepository(db)
    candidate = cand_repo.get_by_evidence_id(evidence.id, current_merchant.id)

    return {
        "status": "PROCESSED",
        "delivery_mode": "SIMULATED",
        "provider_name": "SIMULATED_RAZORPAY",
        "evidence_id": str(evidence.id),
        "evidence_processing_status": evidence.processing_status.value,
        "candidate_id": str(candidate.id) if candidate else None,
        "candidate_normalization_status": candidate.normalization_status.value if candidate else None,
        "is_simulated": True,
        "message": "Demo payment event ingested into evidence and candidate pipeline."
    }
