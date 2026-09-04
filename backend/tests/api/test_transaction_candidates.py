import uuid
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService


def test_transaction_candidates_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    # Merchant A creates manual evidence
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    client.post("/api/v1/evidence/manual", json={
        "amount": "999.99",
        "transaction_type": "MONEY_OUT"
    })

    res_a = client.get("/api/v1/transaction-candidates")
    cand_a_id = res_a.json()["data"][0]["id"]

    # Merchant B cannot access Merchant A's candidate
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    res_b = client.get(f"/api/v1/transaction-candidates/{cand_a_id}")
    assert res_b.status_code == 404
    assert res_b.json()["success"] is False

    res_b_list = client.get("/api/v1/transaction-candidates")
    assert len(res_b_list.json()["data"]) == 0

    app.dependency_overrides.clear()
