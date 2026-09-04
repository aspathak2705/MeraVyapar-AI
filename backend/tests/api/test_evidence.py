import uuid
import io
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.schemas.evidence import ManualEvidenceCreate


def test_manual_evidence_creation_and_candidate_provenance(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    req = ManualEvidenceCreate(
        amount="1500.50",
        transaction_type="MONEY_IN",
        counterparty_name="Kirana Customer",
        description="Payment for daily supplies"
    )

    res = client.post("/api/v1/evidence/manual", json=req.model_dump(mode="json"))
    assert res.status_code in (200, 201)
    data = res.json()["data"]

    assert data["evidence_type"] == "MANUAL_ENTRY"
    assert data["evidence_source"] == "MERCHANT_MANUAL"
    assert data["evidence_strength"] == "MERCHANT_DECLARED"
    evidence_id = data["id"]

    # Verify candidate candidate link
    res_cand = client.get("/api/v1/transaction-candidates")
    assert res_cand.status_code == 200
    cands = res_cand.json()["data"]
    assert len(cands) == 1
    assert cands[0]["primary_evidence_id"] == evidence_id
    assert cands[0]["amount"] == "1500.50"

    app.dependency_overrides.clear()


def test_evidence_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    # Create evidence for Merchant A
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    req = ManualEvidenceCreate(amount="500.00", transaction_type="MONEY_OUT")
    res_a = client.post("/api/v1/evidence/manual", json=req.model_dump(mode="json"))
    evidence_a_id = res_a.json()["data"]["id"]

    # Merchant B tries to fetch Merchant A's evidence
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    res_b = client.get(f"/api/v1/evidence/{evidence_a_id}")
    assert res_b.status_code == 404
    assert res_b.json()["success"] is False

    res_b_list = client.get("/api/v1/evidence")
    assert len(res_b_list.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_idempotent_evidence_submission(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    headers = {"X-Idempotency-Key": "test_idempotency_123"}
    req = ManualEvidenceCreate(amount="200.00", transaction_type="MONEY_IN")

    res1 = client.post("/api/v1/evidence/manual", json=req.model_dump(mode="json"), headers=headers)
    assert res1.status_code in (200, 201)
    id1 = res1.json()["data"]["id"]

    res2 = client.post("/api/v1/evidence/manual", json=req.model_dump(mode="json"), headers=headers)
    assert res2.status_code in (200, 201)
    assert res2.json()["data"]["id"] == id1

    app.dependency_overrides.clear()


def test_invalid_file_mime_type_validation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    fake_exe = io.BytesIO(b"binary data")
    files = {"file": ("malicious.exe", fake_exe, "application/x-msdownload")}
    res = client.post("/api/v1/evidence/file", files=files)

    assert res.status_code == 400
    assert res.json()["success"] is False

    app.dependency_overrides.clear()
