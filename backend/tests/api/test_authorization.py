import uuid
from app.main import app
from app.dependencies.auth import get_current_user_id, get_current_merchant
from app.services.merchant_service import MerchantService


def test_merchant_tenant_isolation(client, db_session):
    service = MerchantService(db_session)

    # 1. Create Merchant A and profile A
    user_a = uuid.uuid4()
    merchant_a = service.initialize_merchant(user_a, "Merchant A Store")
    profile_a_in = service.create_or_update_business_profile(
        merchant_a,
        type("Obj", (object,), {
            "business_name": "Store A",
            "business_type": "Retail",
            "phone_number": "9999999999",
            "city": "Mumbai",
            "state": "Maharashtra"
        })()
    )

    # 2. Create Merchant B
    user_b = uuid.uuid4()
    merchant_b = service.initialize_merchant(user_b, "Merchant B Store")

    # 3. Request business profile as Merchant B
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b

    res_b = client.get("/api/v1/business-profile/me")
    # Merchant B has no profile yet -> 404
    assert res_b.status_code == 404
    assert res_b.json()["success"] is False

    # 4. Merchant B creates their own profile
    profile_b_payload = {
        "business_name": "Store B",
        "business_type": "Wholesale",
        "phone_number": "8888888888",
        "city": "Delhi",
        "state": "Delhi"
    }
    res_b_create = client.put("/api/v1/business-profile/me", json=profile_b_payload)
    assert res_b_create.status_code == 200
    data_b = res_b_create.json()["data"]

    # Verify Merchant B receives Store B, never Store A
    assert data_b["business_name"] == "Store B"
    assert data_b["merchant_id"] == str(merchant_b.id)
    assert data_b["merchant_id"] != str(merchant_a.id)

    app.dependency_overrides.clear()
