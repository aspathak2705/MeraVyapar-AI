import uuid
from datetime import datetime, timedelta, timezone
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.services.evidence_service import EvidenceService
from app.services.evidence_processing_service import EvidenceProcessingService
from app.features.reconciliation.services.reconciliation_service import ReconciliationService
from app.schemas.evidence import ManualEvidenceCreate


def test_payment_promise_lifecycle_and_explicit_fulfillment(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Promise")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    due = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()

    # 1. Create Payment Promise
    res1 = client.post("/api/v1/payment-promises", json={
        "description": "Expected payment for grocery order",
        "promised_amount": "25000.00",
        "currency": "INR",
        "promise_direction": "EXPECTED_INCOMING",
        "due_at": due,
        "source": "MERCHANT_DECLARED"
    })
    assert res1.status_code == 200
    p_data = res1.json()["data"]
    promise_id = p_data["id"]
    assert p_data["status"] == "OPEN"
    assert p_data["promised_amount"] == "25000.00"

    # 2. Transaction with SAME amount arrives -> Must NOT auto-fulfill promise!
    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)
    rec_service = ReconciliationService(db_session)

    ev = evidence_service.create_manual_evidence(
        merchant.id,
        ManualEvidenceCreate(amount="25000.00", transaction_type="MONEY_IN", description="Incoming transfer")
    )
    processor.process_evidence(ev)
    rec_service.run_reconciliation(merchant.id)

    # Verify promise remains OPEN
    res_get = client.get(f"/api/v1/payment-promises/{promise_id}")
    assert res_get.json()["data"]["status"] == "OPEN"
    assert res_get.json()["data"]["fulfilled_at"] is None

    # 3. Explicit Merchant Fulfillment -> Changes status to FULFILLED
    res_fulfill = client.post(f"/api/v1/payment-promises/{promise_id}/fulfill", json={"fulfillment_reference": "REF_BANK_999"})
    assert res_fulfill.status_code == 200
    fulfilled_data = res_fulfill.json()["data"]
    assert fulfilled_data["status"] == "FULFILLED"
    assert fulfilled_data["fulfilled_at"] is not None
    assert len(fulfilled_data["events"]) >= 2

    app.dependency_overrides.clear()


def test_payment_promise_invalid_amount_rejection(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Promise")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    due = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()

    res = client.post("/api/v1/payment-promises", json={
        "description": "Invalid amount promise",
        "promised_amount": "0.00",
        "due_at": due
    })
    assert res.status_code == 422  # Pydantic validation error

    app.dependency_overrides.clear()
