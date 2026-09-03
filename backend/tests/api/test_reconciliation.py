import uuid
from decimal import Decimal
from app.main import app
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.services.evidence_service import EvidenceService
from app.services.evidence_processing_service import EvidenceProcessingService
from app.schemas.evidence import ManualEvidenceCreate, TextEvidenceCreate
from app.models.financial_evidence import EvidenceType, EvidenceStrength
from app.repositories.reconciliation_repository import ReconciliationRepository


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

    # Verify canonical transaction created
    res_canon = client.get("/api/v1/canonical-transactions")
    assert res_canon.status_code == 200
    txs = res_canon.json()["data"]
    assert len(txs) == 1
    tx = txs[0]
    assert tx["amount"] == "5000.00"
    assert tx["reconciliation_status"] == "RECONCILED"

    app.dependency_overrides.clear()


def test_reconciliation_ambiguous_candidates_no_canonical_created(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # Two ₹500 transactions with no counterparty, no reference -> Ambiguous candidates
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

    # Ambiguous candidates trigger review attempt; NO Canonical Transaction created!
    assert rec_data["candidates_reconciled"] == 0
    assert rec_data["candidates_requiring_review"] == 2
    assert rec_data["canonical_transactions_created"] == 0

    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_reconciliation_conflicting_candidates_no_canonical_created(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # ₹5,000 vs ₹5,500 for same counterparty -> Conflicting amounts
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

    # Conflicting candidates trigger review attempt; NO Canonical Transaction created!
    assert rec_data["candidates_reconciled"] == 0
    assert rec_data["candidates_requiring_review"] == 2
    assert rec_data["canonical_transactions_created"] == 0

    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_reconciliation_weak_candidate_no_canonical_created(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # Ingest text evidence that cannot be extracted reliably (missing amount)
    ev = evidence_service.create_text_evidence(
        merchant_a.id,
        TextEvidenceCreate(
            evidence_type=EvidenceType.OTHER,
            raw_text="Random conversational message without financial facts"
        )
    )
    ev.evidence_strength = EvidenceStrength.UNVERIFIED
    processor.process_evidence(ev)

    res_rec = client.post("/api/v1/reconciliation/run")
    assert res_rec.status_code == 200
    rec_data = res_rec.json()["data"]

    # Weak candidate remains in candidate layer; NO Canonical Transaction created!
    assert rec_data["canonical_transactions_created"] == 0

    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 0

    app.dependency_overrides.clear()


def test_reconciliation_strong_standalone_candidate_creates_canonical(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    app.dependency_overrides[get_current_merchant] = lambda: merchant_a

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    # Strong standalone manual entry
    ev = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="1500.00", transaction_type="MONEY_OUT", counterparty_name="Vendor Y")
    )
    processor.process_evidence(ev)

    res_rec = client.post("/api/v1/reconciliation/run")
    assert res_rec.status_code == 200
    rec_data = res_rec.json()["data"]

    # Strong standalone candidate creates 1 Canonical Transaction
    assert rec_data["canonical_transactions_created"] == 1
    assert rec_data["candidates_unresolved"] == 1

    res_canon = client.get("/api/v1/canonical-transactions")
    assert len(res_canon.json()["data"]) == 1

    app.dependency_overrides.clear()


def test_reconciliation_tenant_isolation(client, db_session):
    service = MerchantService(db_session)
    merchant_a = service.initialize_merchant(uuid.uuid4(), "Store A")
    merchant_b = service.initialize_merchant(uuid.uuid4(), "Store B")

    evidence_service = EvidenceService(db_session)
    processor = EvidenceProcessingService(db_session)

    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    ev_a = evidence_service.create_manual_evidence(
        merchant_a.id,
        ManualEvidenceCreate(amount="1000.00", transaction_type="MONEY_OUT", counterparty_name="Shared Vendor")
    )
    processor.process_evidence(ev_a)

    app.dependency_overrides[get_current_merchant] = lambda: merchant_b
    ev_b = evidence_service.create_manual_evidence(
        merchant_b.id,
        ManualEvidenceCreate(amount="1000.00", transaction_type="MONEY_OUT", counterparty_name="Shared Vendor")
    )
    processor.process_evidence(ev_b)

    app.dependency_overrides[get_current_merchant] = lambda: merchant_a
    res_rec_a = client.post("/api/v1/reconciliation/run")
    assert res_rec_a.status_code == 200
    data_a = res_rec_a.json()["data"]
    assert data_a["candidates_examined"] == 1
    assert data_a["candidates_reconciled"] == 0

    res_canon_a = client.get("/api/v1/canonical-transactions")
    assert len(res_canon_a.json()["data"]) == 1

    app.dependency_overrides.clear()
