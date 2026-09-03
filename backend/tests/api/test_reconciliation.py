import uuid
from decimal import Decimal
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.services.evidence_service import EvidenceService
from app.services.evidence_processing_service import EvidenceProcessingService
from app.schemas.evidence import ManualEvidenceCreate, TextEvidenceCreate
from app.models.financial_evidence import EvidenceType


def test_reconciliation_exact_strong_match(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # 1. Candidate A: Manual entry "Paid ABC Traders ₹5,000 via UPI"
    ev1 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(
            amount="5000.00",
            transaction_type="MONEY_OUT",
            counterparty_name="ABC Traders",
            payment_mode="UPI",
            description="Payment to ABC Traders"
        )
    )
    processor.process_evidence(ev1)

    # 2. Candidate B: SMS text "Rs 5,000 debited via UPI"
    ev2 = evidence_service.create_text_evidence(
        merchant_a.id,
        TextEvidenceCreate(
            evidence_type=EvidenceType.BANK_SMS,
            raw_text="Rs. 5,000.00 debited via UPI to ABC Traders"
        )
    )
    processor.process_evidence(ev2)

    # 3. Run reconciliation pass
    res_rec = client.post("/api/v1/reconciliation/run")
    assert res_rec.status_code == 200
    rec_data = res_rec.json()["data"]

    assert rec_data["candidates_examined"] == 2
    assert rec_data["canonical_transactions_created"] == 1
    assert rec_data["candidates_reconciled"] == 2

    # Verify canonical transaction
    res_canon = client.get("/api/v1/canonical-transactions")
    assert res_canon.status_code == 200
    txs = res_canon.json()["data"]
    assert len(txs) == 1
    tx = txs[0]
    assert tx["amount"] == "5000.00"
    assert tx["reconciliation_status"] == "RECONCILED"
    assert len(tx["candidate_links"]) == 2

    app.dependency_overrides.clear()


def test_reconciliation_amount_alone_insufficient(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # Two ₹500 transactions with no counterparty, no reference, different dates
    ev1 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="500.00", transaction_type="MONEY_OUT")
    )
    processor.process_evidence(ev1)

    ev2 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="500.00", transaction_type="MONEY_OUT")
    )
    processor.process_evidence(ev2)

    res_rec = client.post("/api/v1/reconciliation/run")
    assert res_rec.status_code == 200
    rec_data = res_rec.json()["data"]

    # Exact amount alone without counterparty/time signal requires review
    assert rec_data["candidates_reconciled"] == 0
    assert rec_data["candidates_requiring_review"] == 2

    app.dependency_overrides.clear()


def test_reconciliation_amount_conflict(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # ₹5,000 vs ₹5,500 for same counterparty -> Conflicting amounts, not merged
    ev1 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="5000.00", transaction_type="MONEY_OUT", counterparty_name="Supplier X")
    )
    processor.process_evidence(ev1)

    ev2 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="5500.00", transaction_type="MONEY_OUT", counterparty_name="Supplier X")
    )
    processor.process_evidence(ev2)

    res_rec = client.post("/api/v1/reconciliation/run")
    assert res_rec.status_code == 200
    rec_data = res_rec.json()["data"]

    assert rec_data["candidates_reconciled"] == 0
    assert rec_data["candidates_unresolved"] == 2

    res_canon = client.get("/api/v1/canonical-transactions")
    txs = res_canon.json()["data"]
    assert len(txs) == 2
    assert txs[0]["reconciliation_status"] == "UNRESOLVED"
    assert txs[1]["reconciliation_status"] == "UNRESOLVED"

    app.dependency_overrides.clear()


def test_reconciliation_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # Merchant A submits candidate
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    ev_a = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="1000.00", transaction_type="MONEY_OUT", counterparty_name="Shared Vendor")
    )
    processor.process_evidence(ev_a)

    # Merchant B submits candidate with identical values
    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    ev_b = evidence_service.create_manual_evidence(
        merchant_b.id,
        ManualEvidenceCreate(amount="1000.00", transaction_type="MONEY_OUT", counterparty_name="Shared Vendor")
    )
    processor.process_evidence(ev_b)

    # Run reconciliation for Merchant A
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    res_rec_a = client.post("/api/v1/reconciliation/run")
    assert res_rec_a.status_code == 200
    data_a = res_rec_a.json()["data"]
    assert data_a["candidates_examined"] == 1
    assert data_a["candidates_reconciled"] == 0

    # Verify Merchant A has 1 canonical transaction
    res_canon_a = client.get("/api/v1/canonical-transactions")
    assert len(res_canon_a.json()["data"]) == 1

    app.dependency_overrides.clear()


def test_reconciliation_idempotency_run(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    ev1 = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="2000.00", transaction_type="MONEY_IN", counterparty_name="Client Z")
    )
    processor.process_evidence(ev1)

    # First run
    res1 = client.post("/api/v1/reconciliation/run")
    assert res1.status_code == 200
    data1 = res1.json()["data"]
    assert data1["candidates_examined"] == 1

    # Second run (repeated execution)
    res2 = client.post("/api/v1/reconciliation/run")
    assert res2.status_code == 200
    data2 = res2.json()["data"]
    # 0 unlinked candidates examined on second run
    assert data2["candidates_examined"] == 0

    # Total canonical transactions remains 1
    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 1

    app.dependency_overrides.clear()
