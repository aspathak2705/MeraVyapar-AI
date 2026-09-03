from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
from app.parsers.base import ParsedTransactionResult
from app.models.transaction_candidate import TransactionType, PaymentMode


class TransactionNormalizationService:
    @staticmethod
    def normalize_parsed_result(result: ParsedTransactionResult) -> ParsedTransactionResult:
        # 1. Normalize amount to 2 decimal places using Decimal ROUND_HALF_UP
        norm_amount: Optional[Decimal] = None
        if result.amount is not None:
            try:
                norm_amount = result.amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            except Exception:
                norm_amount = result.amount

        # 2. Normalize currency
        norm_currency = (result.currency or "INR").strip().upper()

        # 3. Clean and trim counterparty name
        norm_counterparty: Optional[str] = None
        if result.counterparty_name:
            clean = result.counterparty_name.strip()
            norm_counterparty = clean if clean else None

        # 4. Clean description
        norm_description: Optional[str] = None
        if result.description:
            clean = result.description.strip()
            norm_description = clean if clean else None

        return ParsedTransactionResult(
            amount=norm_amount,
            currency=norm_currency,
            transaction_type=result.transaction_type or TransactionType.UNKNOWN,
            counterparty_name=norm_counterparty,
            payment_mode=result.payment_mode or PaymentMode.UNKNOWN,
            transaction_timestamp=result.transaction_timestamp,
            reference_number=result.reference_number,
            description=norm_description,
            parse_success=result.parse_success,
            parse_status_message=result.parse_status_message
        )
