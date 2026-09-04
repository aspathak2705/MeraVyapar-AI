import uuid
from app.main import app
from app.dependencies.auth import get_current_user_id, get_current_merchant
from app.models.merchant import Merchant


def test_merchant_initialization_idempotency(client, db_session):
    test_user_id = uuid.uuid4()

    app.dependency_overrides[get_current_user_id] = lambda: test_user_id

    # 1. First initialization
    res1 = client.post("/api/v1/merchants/initialize", json={"display_name": "Test Merchant Store"})
    assert res1.status_code == 200
    data1 = res1.json()["data"]
    assert data1["display_name"] == "Test Merchant Store"
    merchant_id_1 = data1["id"]

    # 2. Second initialization (idempotency test)
    res2 = client.post("/api/v1/merchants/initialize", json={"display_name": "Test Merchant Store"})
    assert res2.status_code == 200
    data2 = res2.json()["data"]
    assert data2["id"] == merchant_id_1

    # 3. Read-only me endpoint
    merchant_obj = db_session.query(Merchant).filter(Merchant.id == uuid.UUID(merchant_id_1)).first()
    app.dependency_overrides[get_current_merchant] = lambda: merchant_obj

    res3 = client.get("/api/v1/merchants/me")
    assert res3.status_code == 200
    data3 = res3.json()["data"]
    assert data3["id"] == merchant_id_1

    app.dependency_overrides.clear()
