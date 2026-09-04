import uuid
from decimal import Decimal
from app.parsers.rule_based_transaction_parser import RuleBasedTransactionParser
from app.services.transaction_normalization_service import TransactionNormalizationService
from app.models.financial_evidence import FinancialEvidence, EvidenceType, EvidenceSource, EvidenceStrength, ProcessingStatus
from app.models.transaction_candidate import TransactionType


def test_money_precision_preservation():
    # Verify exact Decimal precision (1000.10 does not drift to floating point)
    raw_amt = "1000.10"
    dec_amt = Decimal(raw_amt)
    evidence = FinancialEvidence(
        merchant_id=uuid.uuid4(),
        evidence_type=EvidenceType.MANUAL_ENTRY,
        evidence_source=EvidenceSource.MERCHANT_MANUAL,
        evidence_strength=EvidenceStrength.MERCHANT_DECLARED,
        metadata_info={"amount": raw_amt, "transaction_type": "MONEY_OUT"}
    )

    parser = RuleBasedTransactionParser()
    parsed = parser.parse(evidence)
    normalized = TransactionNormalizationService.normalize_parsed_result(parsed)

    assert normalized.amount == Decimal("1000.10")
    assert str(normalized.amount) == "1000.10"
    assert normalized.amount != 1000.0999999999


def test_ambiguous_text_does_not_fabricate_amount():
    text = "Hello Ramesh, please call me back tomorrow about the shop keys."
    evidence = FinancialEvidence(
        merchant_id=uuid.uuid4(),
        evidence_type=EvidenceType.BANK_SMS,
        evidence_source=EvidenceSource.MERCHANT_MANUAL,
        evidence_strength=EvidenceStrength.AMBIGUOUS,
        raw_text=text
    )

    parser = RuleBasedTransactionParser()
    parsed = parser.parse(evidence)
    normalized = TransactionNormalizationService.normalize_parsed_result(parsed)

    # Ambiguous text must NOT fabricate an amount or direction
    assert normalized.amount is None
    assert normalized.transaction_type == TransactionType.UNKNOWN
    assert normalized.parse_success is False


def test_deterministic_text_extraction():
    text = "Rs. 1,250.00 debited from a/c XX1234 on 03-Sep-26 via UPI"
    evidence = FinancialEvidence(
        merchant_id=uuid.uuid4(),
        evidence_type=EvidenceType.BANK_SMS,
        evidence_source=EvidenceSource.MERCHANT_MANUAL,
        evidence_strength=EvidenceStrength.AMBIGUOUS,
        raw_text=text
    )

    parser = RuleBasedTransactionParser()
    parsed = parser.parse(evidence)
    normalized = TransactionNormalizationService.normalize_parsed_result(parsed)

    assert normalized.amount == Decimal("1250.00")
    assert normalized.transaction_type == TransactionType.MONEY_OUT
    assert normalized.parse_success is True
