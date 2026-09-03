import uuid
import io
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService


def test_manual_evidence_creation_and_candidate_provenance(client, db_session):
    service = MerchantService(db_session)
    user_a = uuid.uuid4()
    merchant_a = service.initialize_merchant(user_a, "Store A")

    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    payload = {
        "amount": "5000.50",
        "currency": "INR",
        "transaction_type": "MONEY_OUT",
        "description": "Payment to Kirana Supplier",
        "counterparty_name": "Kirana WholeSaler",
        "payment_mode": "UPI"
    }

    res = client.post("/api/v1/evidence/manual", json=payload)
    assert res.status_code == 201
    data = res.json()["data"]

    assert data["evidence_type"] == "MANUAL_ENTRY"
    assert data["evidence_strength"] == "MERCHANT_DECLARED"
    evidence_id = data["id"]

    # Verify candidate created with primary_evidence_id provenance
    res_cand = client.get("/api/v1/transaction-candidates")
    assert res_cand.status_code == 200
    cands = res_cand.json()["data"]
    assert len(cands) == 1
    assert cands[0]["primary_evidence_id"] == evidence_id
    assert cands[0]["amount"] == "5000.50"
    assert cands[0]["transaction_type"] == "MONEY_OUT"

    app.dependency_overrides.clear()


def test_evidence_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    # Merchant A submits evidence
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    res_a = client.post("/api/v1/evidence/manual", json={
        "amount": "1000.00",
        "transaction_type": "MONEY_IN"
    })
    evidence_a_id = res_a.json()["data"]["id"]

    # Merchant B attempts to access Merchant A's evidence
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    res_b_access = client.get(f"/api/v1/evidence/{evidence_a_id}")
    assert res_b_access.status_code == 404
    assert res_b_access.json()["success"] is False

    # Merchant B list evidence -> 0 records
    res_b_list = client.get("/api/v1/evidence")
    assert len(res_b_list.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_idempotent_evidence_submission(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    headers = {"X-Idempotency-Key": "unique-req-12345"}
    payload = {"amount": "250.00", "transaction_type": "MONEY_IN"}

    res1 = client.post("/api/v1/evidence/manual", json=payload, headers=headers)
    assert res1.status_code == 201
    id1 = res1.json()["data"]["id"]

    # Repeated request with same idempotency key returns same evidence
    res2 = client.post("/api/v1/evidence/manual", json=payload, headers=headers)
    assert res2.status_code == 201
    assert res2.json()["data"]["id"] == id1

    app.dependency_overrides.clear()


def test_invalid_file_mime_type_validation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    fake_exe = io.BytesIO(b"binary data")
    files = {"file": ("malicious.exe", fake_exe, "application/x-msdownload")}
    res = client.post("/api/v1/evidence/file", files=files)

    assert res.status_code == 422
    assert res.json()["success"] is False
    assert "Unsupported file MIME type" in res.json()["message"]

    app.dependency_overrides.clear()
