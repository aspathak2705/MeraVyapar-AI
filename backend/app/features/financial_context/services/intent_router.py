import re
from typing import Tuple, Optional


class DeterministicIntentRouter:
    OUT_OF_SCOPE_KEYWORDS = [
        "stock", "loan", "invest", "crypto", "mutual fund",
        "share market", "forecast", "revenue next year",
        "trading", "deposit interest", "tax advice"
    ]

    @classmethod
    def classify_intent(cls, question: str) -> Tuple[str, bool, Optional[str]]:
        if not question or not question.strip():
            return "OUT_OF_SCOPE", False, "Empty query provided."

        lower_q = question.lower().strip()

        for kw in cls.OUT_OF_SCOPE_KEYWORDS:
            if kw in lower_q:
                return (
                    "OUT_OF_SCOPE",
                    False,
                    f"MeraVyapar AI handles merchant evidence, receivables, and payment promises. Market advisory, loans, and investment recommendations are out of scope."
                )

        if any(w in lower_q for w in ["receivable", "pending payment", "who owes", "incoming payment", "due payment"]):
            return "RECEIVABLE_STATUS", True, None

        if any(w in lower_q for w in ["promise", "promised", "due soon", "due date"]):
            return "PAYMENT_PROMISE_STATUS", True, None

        if any(w in lower_q for w in ["customer", "vendor", "counterparty", "supplier", "client"]):
            return "COUNTERPARTY_CONTEXT", True, None

        if any(w in lower_q for w in ["why", "explain", "event", "overdue", "attention"]):
            return "EVENT_EXPLANATION", True, None

        return "MERCHANT_ATTENTION", True, None
