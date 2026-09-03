from datetime import timedelta
from typing import List, Tuple, Dict, Any
from app.models.transaction_candidate import TransactionCandidate, TransactionType, PaymentMode
from app.models.reconciliation_attempt import ReconciliationDecision


class ReconciliationRuleEngine:
    @staticmethod
    def evaluate_pair(
        cand_a: TransactionCandidate,
        cand_b: TransactionCandidate
    ) -> Tuple[ReconciliationDecision, List[str], Dict[str, Any]]:
        reason_codes: List[str] = []
        snapshot: Dict[str, Any] = {
            "cand_a_id": str(cand_a.id),
            "cand_b_id": str(cand_b.id),
            "cand_a_amount": str(cand_a.amount) if cand_a.amount is not None else None,
            "cand_b_amount": str(cand_b.amount) if cand_b.amount is not None else None,
            "cand_a_type": cand_a.transaction_type.value,
            "cand_b_type": cand_b.transaction_type.value,
            "cand_a_counterparty": cand_a.counterparty_name,
            "cand_b_counterparty": cand_b.counterparty_name,
        }

        # 1. Amount Conflict Check
        if cand_a.amount is not None and cand_b.amount is not None:
            if cand_a.amount != cand_b.amount:
                reason_codes.append("AMOUNT_CONFLICT")
                return ReconciliationDecision.NOT_MATCHED, reason_codes, snapshot
            else:
                reason_codes.append("EXACT_AMOUNT_MATCH")
        else:
            reason_codes.append("MISSING_AMOUNT")

        # 2. Transaction Type Conflict Check
        if cand_a.transaction_type != TransactionType.UNKNOWN and cand_b.transaction_type != TransactionType.UNKNOWN:
            if cand_a.transaction_type != cand_b.transaction_type:
                reason_codes.append("TYPE_CONFLICT")
                return ReconciliationDecision.NOT_MATCHED, reason_codes, snapshot
            else:
                reason_codes.append("SAME_TRANSACTION_TYPE")

        # 3. Payment Mode Match Check
        if cand_a.payment_mode != PaymentMode.UNKNOWN and cand_b.payment_mode != PaymentMode.UNKNOWN:
            if cand_a.payment_mode == cand_b.payment_mode:
                reason_codes.append("SAME_PAYMENT_MODE")

        # 4. Counterparty Match Check
        counterparty_match = False
        if cand_a.counterparty_name and cand_b.counterparty_name:
            c1 = cand_a.counterparty_name.strip().lower()
            c2 = cand_b.counterparty_name.strip().lower()
            if c1 == c2 or c1 in c2 or c2 in c1:
                counterparty_match = True
                reason_codes.append("COUNTERPARTY_MATCH")

        # 5. Reference Number Match Check
        reference_match = False
        if cand_a.reference_number and cand_b.reference_number:
            if cand_a.reference_number.strip().lower() == cand_b.reference_number.strip().lower():
                reference_match = True
                reason_codes.append("REFERENCE_MATCH")

        # 6. Time Proximity Check (within 24 hours)
        time_proximity = False
        if cand_a.transaction_timestamp and cand_b.transaction_timestamp:
            diff = abs(cand_a.transaction_timestamp - cand_b.transaction_timestamp)
            if diff <= timedelta(hours=24):
                time_proximity = True
                reason_codes.append("TIME_PROXIMITY")

        # Decision Matrix:
        # Strong Match Requires: EXACT_AMOUNT_MATCH + SAME_TRANSACTION_TYPE + (COUNTERPARTY_MATCH OR REFERENCE_MATCH OR (SAME_PAYMENT_MODE AND TIME_PROXIMITY))
        if "EXACT_AMOUNT_MATCH" in reason_codes and "SAME_TRANSACTION_TYPE" in reason_codes:
            if counterparty_match or reference_match or ("SAME_PAYMENT_MODE" in reason_codes and time_proximity):
                return ReconciliationDecision.MATCHED, reason_codes, snapshot
            else:
                reason_codes.append("INSUFFICIENT_SIGNALS")
                return ReconciliationDecision.REQUIRES_REVIEW, reason_codes, snapshot

        reason_codes.append("INSUFFICIENT_SIGNALS")
        return ReconciliationDecision.NOT_MATCHED, reason_codes, snapshot
