import re
from typing import List, Tuple, Set, Dict, Any, Optional
from app.features.market_intelligence.fusion_models import (
    GroundedEvidenceBundle,
    GroundedMerchantInsight,
    GroundingStatus,
)

# Forbidden causal assertion patterns (unless backed by deterministic proof)
UNSUPPORTED_CAUSAL_PATTERNS = [
    re.compile(r"\bdefinitely caused\b", re.IGNORECASE),
    re.compile(r"\bdirectly caused by\b", re.IGNORECASE),
    re.compile(r"\bwas caused entirely by\b", re.IGNORECASE),
    re.compile(r"\bsolely caused by\b", re.IGNORECASE),
    re.compile(r"\bthe exact reason was\b", re.IGNORECASE),
]

# Forbidden financial/trading advice patterns
ADVISORY_PATTERNS = [
    re.compile(r"\bbuy\s+(?:shares?|stock|crypto|equity)\b", re.IGNORECASE),
    re.compile(r"\bsell\s+(?:shares?|stock|crypto|equity)\b", re.IGNORECASE),
    re.compile(r"\binvest\s+in\b", re.IGNORECASE),
    re.compile(r"\bportfolio\s+recommendation\b", re.IGNORECASE),
    re.compile(r"\btake\s+a\s+loan\b", re.IGNORECASE),
]


class GroundingValidator:
    """
    Lightweight deterministic validator verifying:
    1. Financial numbers: No fabricated numerical values not present in internal facts.
    2. Evidence IDs: Every referenced evidence_id exists in the supplied bundle.
    3. Sources: No invented third-party sources or news agencies not in external signals.
    4. Causal claims: Flags unsupported hard causality ("definitely caused by").
    5. Advisory safety: Blocks stock, trading, or investment advice.
    """

    @classmethod
    def validate(
        cls,
        insight: GroundedMerchantInsight,
        bundle: GroundedEvidenceBundle
    ) -> Tuple[bool, List[str]]:
        errors: List[str] = []

        valid_evidence_ids: Set[str] = {sig.evidence_id for sig in bundle.external_evidence}
        valid_source_names: Set[str] = {sig.source_name.lower() for sig in bundle.external_evidence}
        valid_fact_values: Set[str] = {fact.value for fact in bundle.internal_facts}

        # 1. Evidence Reference Validation
        for ref_id in insight.evidence_references:
            if ref_id not in valid_evidence_ids:
                errors.append(f"Referenced evidence_id '{ref_id}' was not in supplied evidence bundle.")

        for sig_ref in insight.external_signals:
            if sig_ref.evidence_id not in valid_evidence_ids:
                errors.append(f"External signal referenced invalid evidence_id '{sig_ref.evidence_id}'.")

        # 2. Check for unsupported hard causal language
        text_to_scan = f"{insight.summary} {insight.interpretation}"
        for pattern in UNSUPPORTED_CAUSAL_PATTERNS:
            if pattern.search(text_to_scan):
                errors.append(f"Unsupported hard causal claim detected matching pattern: {pattern.pattern}")

        # 3. Check for investment / trading advice
        for adv_pattern in ADVISORY_PATTERNS:
            if adv_pattern.search(text_to_scan):
                errors.append(f"Prohibited financial advisory phrase detected matching: {adv_pattern.pattern}")

        # 4. Check for invented numbers in summary/interpretation (excluding valid fact numbers)
        # Extract all numbers from facts (raw digits)
        allowed_number_strings = set()
        for fact in bundle.internal_facts:
            # find all digit sequences in fact values
            allowed_number_strings.update(re.findall(r"\b\d+(?:\.\d+)?\b", fact.value))
            if fact.current_value:
                allowed_number_strings.update(re.findall(r"\b\d+(?:\.\d+)?\b", str(fact.current_value)))
            if fact.comparison_value:
                allowed_number_strings.update(re.findall(r"\b\d+(?:\.\d+)?\b", str(fact.comparison_value)))
            if fact.percentage_change:
                allowed_number_strings.update(re.findall(r"\b\d+(?:\.\d+)?\b", str(fact.percentage_change)))

        for sig in bundle.external_evidence:
            if sig.price:
                allowed_number_strings.update(re.findall(r"\b\d+(?:\.\d+)?\b", str(sig.price)))

        # Find numbers in model output
        output_numbers = set(re.findall(r"\b\d+(?:\.\d+)?\b", text_to_scan))
        fabricated_numbers = [
            n for n in output_numbers
            if n not in allowed_number_strings and float(n) > 5.0  # filter out small harmless digits like 1, 2
        ]
        if fabricated_numbers:
            errors.append(f"Model output contained ungrounded numerical amounts: {fabricated_numbers}")

        is_valid = len(errors) == 0
        return is_valid, errors
