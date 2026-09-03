import re
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone
from typing import Optional
from app.parsers.base import TransactionParser, ParsedTransactionResult
from app.models.financial_evidence import FinancialEvidence, EvidenceType
from app.models.transaction_candidate import TransactionType, PaymentMode


class RuleBasedTransactionParser(TransactionParser):
    def parse(self, evidence: FinancialEvidence) -> ParsedTransactionResult:
        # Case 1: Manual Entry with structured metadata
        if evidence.evidence_type == EvidenceType.MANUAL_ENTRY:
            return self._parse_manual_entry(evidence)

        # Case 2: Text Evidence (Bank SMS / Notification text)
        if evidence.raw_text:
            return self._parse_text_evidence(evidence.raw_text)

        # Case 3: File Evidence (Screenshot / Receipt) - No OCR in Phase 1
        return ParsedTransactionResult(
            parse_success=False,
            parse_status_message="File evidence stored; awaiting future OCR/extraction model"
        )

    def _parse_manual_entry(self, evidence: FinancialEvidence) -> ParsedTransactionResult:
        meta = evidence.metadata_info or {}
        raw_amount = meta.get("amount")
        amount = None

        if raw_amount:
            try:
                # Clean amount string and convert to Decimal for strict precision
                clean_amt = str(raw_amount).replace(",", "").strip()
                amount = Decimal(clean_amt)
            except (InvalidOperation, ValueError):
                amount = None

        tx_type_str = meta.get("transaction_type", "UNKNOWN")
        try:
            tx_type = TransactionType(tx_type_str)
        except ValueError:
            tx_type = TransactionType.UNKNOWN

        mode_str = meta.get("payment_mode", "UNKNOWN")
        try:
            payment_mode = PaymentMode(mode_str)
        except ValueError:
            payment_mode = PaymentMode.UNKNOWN

        tx_timestamp = None
        raw_ts = meta.get("transaction_timestamp")
        if raw_ts:
            try:
                tx_timestamp = datetime.fromisoformat(raw_ts.replace("Z", "+00:00"))
            except ValueError:
                tx_timestamp = None

        return ParsedTransactionResult(
            amount=amount,
            currency=meta.get("currency", "INR"),
            transaction_type=tx_type,
            counterparty_name=meta.get("counterparty_name"),
            payment_mode=payment_mode,
            transaction_timestamp=tx_timestamp or evidence.received_at,
            description=evidence.raw_text,
            parse_success=True if amount is not None else False,
            parse_status_message="Manual entry parsed successfully"
        )

    def _parse_text_evidence(self, text: str) -> ParsedTransactionResult:
        # Conservative deterministic text parsing
        # Example 1: "Rs. 1,250 debited" / "INR 500 credited"
        debited_match = re.search(r'(?:Rs\.?|INR)\s*([\d,]+\.?\d*)\s*(?:debited|paid|sent)', text, re.IGNORECASE)
        credited_match = re.search(r'(?:Rs\.?|INR)\s*([\d,]+\.?\d*)\s*(?:credited|received)', text, re.IGNORECASE)

        amount: Optional[Decimal] = None
        tx_type = TransactionType.UNKNOWN
        parse_success = False

        if debited_match:
            try:
                clean_amt = debited_match.group(1).replace(",", "")
                amount = Decimal(clean_amt)
                tx_type = TransactionType.MONEY_OUT
                parse_success = True
            except (InvalidOperation, ValueError):
                pass
        elif credited_match:
            try:
                clean_amt = credited_match.group(1).replace(",", "")
                amount = Decimal(clean_amt)
                tx_type = TransactionType.MONEY_IN
                parse_success = True
            except (InvalidOperation, ValueError):
                pass

        # Extract payment mode if explicitly stated
        payment_mode = PaymentMode.UNKNOWN
        if "UPI" in text.upper():
            payment_mode = PaymentMode.UPI
        elif "NEFT" in text.upper() or "RTGS" in text.upper() or "IMPS" in text.upper():
            payment_mode = PaymentMode.BANK_TRANSFER
        elif "CARD" in text.upper():
            payment_mode = PaymentMode.CARD

        return ParsedTransactionResult(
            amount=amount,
            currency="INR",
            transaction_type=tx_type,
            payment_mode=payment_mode,
            description=text,
            parse_success=parse_success,
            parse_status_message="Deterministic text rule match" if parse_success else "Ambiguous text; requires review"
        )
