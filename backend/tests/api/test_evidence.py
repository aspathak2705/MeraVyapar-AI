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


def test_mobile_evidence_registration_and_extraction_pipeline(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_id = str(uuid.uuid4())
    fake_sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    reg_payload = {
        "evidence_id": evidence_id,
        "evidence_type": "PAYMENT_SCREENSHOT",
        "content_type": "image/jpeg",
        "original_filename": "payment_proof.jpg",
        "size_bytes": 10240,
        "client_sha256": fake_sha256,
        "storage_version": 1
    }

    # 1. Register evidence
    res_reg = client.post("/api/v1/evidence/register", json=reg_payload)
    assert res_reg.status_code in (200, 201)
    reg_data = res_reg.json()["data"]
    assert reg_data["id"] == evidence_id
    assert reg_data["processing_status"] == "AWAITING_EXTRACTION"
    assert "data/user" not in (reg_data["storage_object_key"] or "")

    # 2. Duplicate registration is idempotent
    res_reg_dup = client.post("/api/v1/evidence/register", json=reg_payload)
    assert res_reg_dup.status_code in (200, 201)
    assert res_reg_dup.json()["data"]["id"] == evidence_id

    # 3. Submit extraction with matching hash
    extract_payload = {
        "client_sha256": fake_sha256,
        "amount": "3500.00",
        "currency": "INR",
        "transaction_type": "MONEY_IN",
        "counterparty_name": "Ramesh Kumar",
        "payment_mode": "UPI",
        "reference_number": "UPI9876543210",
        "extraction_engine": "TFLiteExtractionEngine"
    }

    res_ext = client.post(f"/api/v1/evidence/{evidence_id}/extraction", json=extract_payload)
    assert res_ext.status_code == 200
    ext_data = res_ext.json()["data"]
    assert ext_data["processing_status"] == "PARSED"

    # 4. Verify candidate created with full provenance
    res_cands = client.get("/api/v1/transaction-candidates")
    assert res_cands.status_code == 200
    cands = res_cands.json()["data"]
    assert len(cands) == 1
    assert cands[0]["primary_evidence_id"] == evidence_id
    assert cands[0]["amount"] == "3500.00"
    assert cands[0]["counterparty_name"] == "Ramesh Kumar"

    app.dependency_overrides.clear()


def test_mobile_evidence_registration_validation_and_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    evidence_id = str(uuid.uuid4())

    # Unsupported MIME type
    res_bad_mime = client.post("/api/v1/evidence/register", json={
        "evidence_id": evidence_id,
        "content_type": "application/x-executable",
        "original_filename": "bad.exe",
        "size_bytes": 100,
        "client_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    })
    assert res_bad_mime.status_code == 400

    # Invalid SHA-256 pattern
    res_bad_hash = client.post("/api/v1/evidence/register", json={
        "evidence_id": evidence_id,
        "content_type": "image/png",
        "original_filename": "valid.png",
        "size_bytes": 100,
        "client_sha256": "not_a_valid_sha256"
    })
    assert res_bad_hash.status_code == 422

    # Register valid evidence under Merchant A
    valid_hash = "a" * 64
    res_ok = client.post("/api/v1/evidence/register", json={
        "evidence_id": evidence_id,
        "content_type": "image/png",
        "original_filename": "valid.png",
        "size_bytes": 1024,
        "client_sha256": valid_hash
    })
    assert res_ok.status_code in (200, 201)

    # Merchant B cannot submit extraction for Merchant A's evidence
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    res_b_hack = client.post(f"/api/v1/evidence/{evidence_id}/extraction", json={
        "client_sha256": valid_hash,
        "amount": "999.00"
    })
    assert res_b_hack.status_code == 404

    app.dependency_overrides.clear()


def test_decommissioning_and_untrusted_extraction_audit(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Audit")

    # 1. Unauthenticated registration rejected (missing Authorization header)
    res_unauth = client.post("/api/v1/evidence/register", json={
        "evidence_id": str(uuid.uuid4()),
        "content_type": "image/png",
        "original_filename": "receipt.png",
        "size_bytes": 1000,
        "client_sha256": "b" * 64
    })
    assert res_unauth.status_code in (401, 403, 422)

    # 2. Authenticated registration does NOT call Supabase Storage
    app.dependency_overrides[get_current_merchant] = lambda: merchant
    evidence_id = str(uuid.uuid4())
    correct_hash = "c" * 64
    wrong_hash = "d" * 64

    res_reg = client.post("/api/v1/evidence/register", json={
        "evidence_id": evidence_id,
        "content_type": "image/png",
        "original_filename": "receipt.png",
        "size_bytes": 2048,
        "client_sha256": correct_hash
    })
    assert res_reg.status_code in (200, 201)
    ev_data = res_reg.json()["data"]
    assert ev_data["metadata_info"]["submission_method"] == "mobile_app_private"
    assert ev_data["metadata_info"]["storage_owner"] == "mobile_device"

    # 3. SHA-256 mismatch on extraction submission is rejected
    res_mismatch = client.post(f"/api/v1/evidence/{evidence_id}/extraction", json={
        "client_sha256": wrong_hash,
        "amount": "5000.00"
    })
    assert res_mismatch.status_code == 400

    # 4. Untrusted client values are sanitized/normalized by backend (e.g. malformed amount)
    res_clean_ext = client.post(f"/api/v1/evidence/{evidence_id}/extraction", json={
        "client_sha256": correct_hash,
        "amount": "  12,500.50  ",
        "currency": "INR",
        "counterparty_name": "  ABC Wholesale Dist  ",
        "payment_mode": "BANK_TRANSFER",
        "reference_number": "NEFT12345"
    })
    assert res_clean_ext.status_code == 200
    res_cands = client.get("/api/v1/transaction-candidates")
    cand = res_cands.json()["data"][0]
    assert cand["amount"] == "12500.50"
    assert cand["currency"] == "INR"
    assert cand["counterparty_name"] == "ABC Wholesale Dist"
    assert cand["payment_mode"] == "BANK_TRANSFER"

    app.dependency_overrides.clear()


