import uuid
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.services.evidence_service import EvidenceService
from app.services.evidence_processing_service import EvidenceProcessingService
from app.schemas.evidence import ManualEvidenceCreate


def test_canonical_transactions_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # Merchant A creates evidence and runs reconciliation
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    ev_a = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="750.00", transaction_type="MONEY_OUT")
    )
    processor.process_evidence(ev_a)
    client.post("/api/v1/reconciliation/run")

    res_a = client.get("/api/v1/canonical-transactions")
    canon_a_id = res_a.json()["data"][0]["id"]

    # Merchant B tries to access Merchant A's canonical transaction
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    res_b = client.get(f"/api/v1/canonical-transactions/{canon_a_id}")
    assert res_b.status_code == 404
    assert res_b.json()["success"] is False

    res_b_list = client.get("/api/v1/canonical-transactions")
    assert len(res_b_list.json()["data"]) == 0

    app.dependency_overrides.clear()
