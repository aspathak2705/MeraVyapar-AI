import uuid
import io
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.models.capture_source_setting import CaptureSourceType


def test_capture_shared_text(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    res = client.post("/api/v1/capture/shared-text", json={"text": "Paid Rs. 2,500.00 to ABC Traders via UPI"})
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["evidence_source"] == "USER_SHARED_TEXT"
    assert data["processing_status"] in ("PARSED", "NORMALIZED")

    # Verify candidate created but NO direct canonical transaction
    res_cands = client.get("/api/v1/transaction-candidates")
    assert len(res_cands.json()["data"]) == 1

    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_capture_promotional_notification_no_candidate(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    res = client.post("/api/v1/capture/notification", json={
        "provider_identifier": "gpay",
        "title": "Rewards Alert",
        "text": "Congratulations! You won Rs 100 cashback in your scratch card!"
    })
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["processing_status"] == "NOT_FINANCIAL_EVENT"

    res_cands = client.get("/api/v1/transaction-candidates")
    assert len(res_cands.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_capture_otp_sms_no_candidate(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    res = client.post("/api/v1/capture/sms", json={
        "sender": "HDFCBK",
        "body": "Your OTP for login is 123456. Valid for 10 minutes. Do not share."
    })
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["processing_status"] == "NOT_FINANCIAL_EVENT"

    res_cands = client.get("/api/v1/transaction-candidates")
    assert len(res_cands.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_capture_transaction_sms_pipeline(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    res = client.post("/api/v1/capture/sms", json={
        "sender": "HDFCBK",
        "body": "Rs 5,000.00 debited from A/c XXXX via UPI to Supplier Y",
        "external_event_id": "sms_evt_1001"
    })
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["evidence_source"] == "SMS_CAPTURE"
    assert data["processing_status"] == "PARSED"

    res_cands = client.get("/api/v1/transaction-candidates")
    assert len(res_cands.json()["data"]) == 1

    # Directly no canonical transaction created
    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_capture_provider_settings_filtering(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    # Disable 'untrusted_app' provider setting
    client.put("/api/v1/capture/settings", json={
        "source_type": "NOTIFICATION_CAPTURE",
        "provider_identifier": "untrusted_app",
        "enabled": False
    })

    # Post notification from disabled provider
    res = client.post("/api/v1/capture/notification", json={
        "provider_identifier": "untrusted_app",
        "text": "Rs 500 debited via untrusted app"
    })
    assert res.status_code == 200
    assert res.json()["data"] is None

    app.dependency_overrides.clear()


def test_capture_duplicate_notification_ignored(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    req = {
        "provider_identifier": "gpay",
        "title": "Payment Sent",
        "text": "Rs 1,200 paid to Kirana Store",
        "external_event_id": "dup_notif_789"
    }

    res1 = client.post("/api/v1/capture/notification", json=req)
    assert res1.status_code == 200
    assert res1.json()["data"] is not None

    res2 = client.post("/api/v1/capture/notification", json=req)
    assert res2.status_code == 200
    assert res2.json()["data"] is None  # Duplicate event ignored

    app.dependency_overrides.clear()


def test_capture_unsupported_file_mime_rejection(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    exe_file = io.BytesIO(b"binary payload")
    res = client.post(
        "/api/v1/capture/shared-file",
        files={"file": ("malicious.exe", exe_file, "application/x-msdownload")}
    )
    assert res.status_code == 400
    assert res.json()["success"] is False

    app.dependency_overrides.clear()


def test_capture_screenshot_awaiting_extraction(client, db_session):
    service = MerchantService(db_session)
    merchant = service.initialize_merchant(uuid.uuid4(), "Store Capture")
    app.dependency_overrides[get_current_merchant] = lambda: merchant

    image_file = io.BytesIO(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR")
    res = client.post(
        "/api/v1/capture/shared-file",
        files={"file": ("receipt.png", image_file, "image/png")}
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["processing_status"] == "AWAITING_EXTRACTION"

    res_cands = client.get("/api/v1/transaction-candidates")
    assert len(res_cands.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_capture_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    # Merchant A disables provider
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    client.put("/api/v1/capture/settings", json={
        "source_type": "NOTIFICATION_CAPTURE",
        "provider_identifier": "shared_provider",
        "enabled": False
    })

    # Merchant B settings remain unaffected
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    res_settings_b = client.get("/api/v1/capture/settings")
    assert len(res_settings_b.json()["data"]) == 0

    res_capture_b = client.post("/api/v1/capture/notification", json={
        "provider_identifier": "shared_provider",
        "text": "Rs 800 paid to Store B"
    })
    assert res_capture_b.status_code == 200
    assert res_capture_b.json()["data"] is not None

    app.dependency_overrides.clear()
