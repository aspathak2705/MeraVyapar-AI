import uuid
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.services.evidence_service import EvidenceService
from app.services.evidence_processing_service import EvidenceProcessingService
from app.features.reconciliation.services.reconciliation_service import ReconciliationService
from app.features.memory.services.counterparty_resolution_service import CounterpartyResolutionService
from app.features.memory.services.financial_memory_backfill_service import FinancialMemoryBackfillService
from app.schemas.evidence import ManualEvidenceCreate


def test_counterparty_resolution_exact_and_ambiguous(db_session):
    resolver = CounterpartyResolutionService(db_session)
    merchant_id = uuid.uuid4()

    # 1. First entry: "ABC Traders"
    cp1 = resolver.resolve_counterparty(merchant_id, "ABC Traders")
    assert cp1 is not None
    assert cp1.display_name == "ABC Traders"

    # 2. Uppercase entry: "ABC TRADERS" -> Exact match with existing
    cp2 = resolver.resolve_counterparty(merchant_id, "ABC TRADERS")
    assert cp2.id == cp1.id

    # 3. Ambiguous name: "ABC Traders Pvt Ltd" -> Separate counterparty, no fuzzy auto-merge
    cp3 = resolver.resolve_counterparty(merchant_id, "ABC Traders Pvt Ltd")
    assert cp3.id != cp1.id


def test_memory_graph_construction_and_timeline(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store Memory")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)
    rec_service = ReconciliationService(db_session)

    # 1. First manual entry for "Supplier X"
    ev1 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="5000.00", transaction_type="MONEY_OUT", counterparty_name="Supplier X")
    )
    processor.process_evidence(ev1)
    rec_service.run_reconciliation(merchant_a.id)

    # Verify counterparty created and listed via API
    res_cps = client.get("/api/v1/counterparties")
    assert res_cps.status_code == 200
    cps = res_cps.json()["data"]
    assert len(cps) == 1
    cp_id = cps[0]["id"]

    # Verify timeline event
    res_tl = client.get(f"/api/v1/counterparties/{cp_id}/timeline")
    assert res_tl.status_code == 200
    events = res_tl.json()["data"]
    assert len(events) == 1
    assert events[0]["event_type"] == "FIRST_TRANSACTION"

    app.dependency_overrides.clear()


def test_memory_graph_idempotency(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store Memory")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)
    rec_service = ReconciliationService(db_session)

    ev1 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="3000.00", transaction_type="MONEY_IN", counterparty_name="Client Z")
    )
    processor.process_evidence(ev1)

    # First reconciliation run
    rec_service.run_reconciliation(merchant_a.id)

    # Second reconciliation run (idempotency check)
    rec_service.run_reconciliation(merchant_a.id)

    res_cps = client.get("/api/v1/counterparties")
    assert len(res_cps.json()["data"]) == 1

    app.dependency_overrides.clear()


def test_memory_graph_cross_merchant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)
    rec_service = ReconciliationService(db_session)

    # Merchant A
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    ev_a = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="1000.00", transaction_type="MONEY_OUT", counterparty_name="Shared Vendor")
    )
    processor.process_evidence(ev_a)
    rec_service.run_reconciliation(merchant_a.id)

    # Merchant B with same counterparty display name
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    ev_b = evidence_service.create_manual_evidence(
        merchant_b.id,
        ManualEvidenceCreate(amount="1000.00", transaction_type="MONEY_OUT", counterparty_name="Shared Vendor")
    )
    processor.process_evidence(ev_b)
    rec_service.run_reconciliation(merchant_b.id)

    # Verify Merchant A counterparties
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    cps_a = client.get("/api/v1/counterparties").json()["data"]

    # Verify Merchant B counterparties
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    cps_b = client.get("/api/v1/counterparties").json()["data"]

    assert len(cps_a) == 1
    assert len(cps_b) == 1
    assert cps_a[0]["id"] != cps_b[0]["id"]

    app.dependency_overrides.clear()


def test_memory_backfill_service_idempotency(db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)
    rec_service = ReconciliationService(db_session)
    backfill_service = FinancialMemoryBackfillService(db_session)

    ev = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="750.00", transaction_type="MONEY_IN", counterparty_name="Customer M")
    )
    processor.process_evidence(ev)
    rec_service.run_reconciliation(merchant_a.id)

    # First backfill run
    cnt1 = backfill_service.backfill_merchant_memory(merchant_a.id)
    # Second backfill run
    cnt2 = backfill_service.backfill_merchant_memory(merchant_a.id)

    assert cnt2 == 0  # Re-running backfill skips already processed transactions
