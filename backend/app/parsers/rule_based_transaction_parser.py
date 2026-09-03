import re
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone
from app.parsers.base import TransactionParser, ParsedTransactionResult
from app.models.financial_evidence import FinancialEvidence, EvidenceType
from app.models.transaction_candidate import TransactionType, PaymentMode


class RuleBasedTransactionParser(TransactionParser):
    def parse(self, evidence: FinancialEvidence) -> ParsedTransactionResult:
        if evidence.evidence_type in (EvidenceType.PAYMENT_SCREENSHOT, EvidenceType.PAYMENT_RECEIPT):
            return ParsedTransactionResult(
                parse_success=False,
                parse_status_message="Awaiting OCR/TFLite extraction",
                is_financial_event=True
            )

        if evidence.evidence_type == EvidenceType.MANUAL_ENTRY and evidence.metadata_info:
            meta = evidence.metadata_info
            amount_str = meta.get("amount")
            amount_val = None
            if amount_str:
                try:
                    amount_val = Decimal(str(amount_str))
                except InvalidOperation:
                    amount_val = None

            tt = TransactionType.UNKNOWN
            if meta.get("transaction_type") == "MONEY_IN":
                tt = TransactionType.MONEY_IN
            elif meta.get("transaction_type") == "MONEY_OUT":
                tt = TransactionType.MONEY_OUT

            pm = PaymentMode.UNKNOWN
            pm_str = meta.get("payment_mode")
            if pm_str in [e.value for e in PaymentMode]:
                pm = PaymentMode(pm_str)

            return ParsedTransactionResult(
                amount=amount_val,
                currency=meta.get("currency", "INR"),
                transaction_type=tt,
                counterparty_name=meta.get("counterparty_name"),
                payment_mode=pm,
                description=meta.get("description"),
                parse_success=True,
                parse_status_message="Parsed from manual entry metadata",
                is_financial_event=True
            )

        text = evidence.raw_text or ""
        if not text.strip():
            return ParsedTransactionResult(
                parse_success=False,
                parse_status_message="Empty raw text",
                is_financial_event=False
            )

        lower_text = text.lower()

        # Non-transaction filter: OTP, Promotional rewards, Loan offers
        non_tx_patterns = [
            r"\botp\b",
            r"verification code",
            r"cashback",
            r"won\b",
            r"scratch card",
            r"special offer",
            r"instant loan",
            r"reward points",
            r"rate your"
        ]
        for pattern in non_tx_patterns:
            if re.search(pattern, lower_text):
                return ParsedTransactionResult(
                    parse_success=False,
                    parse_status_message=f"Non-transaction text detected (matched pattern: {pattern})",
                    is_financial_event=False
                )

        # Money direction check
        tx_type = TransactionType.UNKNOWN
        if any(w in lower_text for w in ["debited", "paid", "sent", "spent", "withdrawn", "debit"]):
            tx_type = TransactionType.MONEY_OUT
        elif any(w in lower_text for w in ["credited", "received", "deposited", "credit"]):
            tx_type = TransactionType.MONEY_IN

        # Amount extraction
        amount_match = re.search(r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)", text, re.IGNORECASE)
        amount_val = None
        if amount_match:
            raw_amt = amount_match.group(1).replace(",", "")
            try:
                amount_val = Decimal(raw_amt)
            except InvalidOperation:
                amount_val = None

        # Payment mode check
        pm = PaymentMode.UNKNOWN
        if "upi" in lower_text:
            pm = PaymentMode.UPI
        elif "bank" in lower_text or "neft" in lower_text or "imps" in lower_text:
            pm = PaymentMode.BANK_TRANSFER

        # Counterparty check
        cp_match = re.search(r"(?:to|from)\s+([A-Za-z0-9\s]{2,30})", text, re.IGNORECASE)
        cp_name = cp_match.group(1).strip() if cp_match else None

        parse_success = amount_val is not None and tx_type != TransactionType.UNKNOWN

        return ParsedTransactionResult(
            amount=amount_val,
            currency="INR",
            transaction_type=tx_type,
            counterparty_name=cp_name,
            payment_mode=pm,
            parse_success=parse_success,
            parse_status_message="Parsed via conservative text rules" if parse_success else "Partial text extraction",
            is_financial_event=True
        )
