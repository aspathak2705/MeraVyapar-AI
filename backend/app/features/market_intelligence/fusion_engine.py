import json
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from openai import OpenAI, RateLimitError, APIError, APIConnectionError, APITimeoutError

from app.core.config import settings
from app.features.market_intelligence.fusion_models import (
    GroundedEvidenceBundle,
    GroundedMerchantInsight,
    GroundingStatus,
    InsightType,
    GroundedEvidenceReference,
)
from app.features.market_intelligence.grounding_guard import GroundingValidator

logger = logging.getLogger(__name__)

FUSION_SYSTEM_PROMPT = """You are a grounded financial explanation engine for Indian micro and small merchants.
Your task is to explain the relationship between verified internal financial facts and retrieved external market evidence.

STRICT REASONING RULES:
1. You are NOT the source of truth. Internal financial facts are deterministic facts.
2. External market evidence consists of market signals and observed indicators.
3. NEVER calculate financial values, totals, or balances. Use ONLY numbers present in internal_facts.
4. Distinguish between FACT (internal records), EXTERNAL SIGNAL (market observations), and INTERPRETATION (potential connection).
5. DO NOT claim unsupported causality. Use cautious phrasing: "may be consistent with", "could be a contributing factor", "external signals suggest". Never state "caused by" or "the reason was".
6. If external evidence is empty, weak, or conflicting, say so explicitly.
7. Every external claim MUST reference the exact evidence_id from external_evidence.
8. NEVER give investment advice, stock recommendations, loan suggestions, or trading advice.

Return ONLY a valid JSON object matching this schema:
{
  "insight_type": "EXPENSE_PRESSURE_EXPLAINED | REVENUE_CHANGE_CONTEXT | CATEGORY_MARKET_SIGNAL | LOCAL_MARKET_CONTEXT | MACRO_CONTEXT | INSUFFICIENT_EXTERNAL_EVIDENCE",
  "title": "Concise headline for the merchant",
  "summary": "1-2 sentence overview of the financial anomaly and market context",
  "external_signals": [
    {"evidence_id": "exact_evidence_id", "claim": "observed market price or demand signal"}
  ],
  "interpretation": "Reasoned connection between internal facts and external signals",
  "grounding_status": "STRONGLY_SUPPORTED | SUPPORTED | POTENTIAL_CONNECTION | INSUFFICIENT_EVIDENCE | CONFLICTING_EVIDENCE",
  "evidence_references": ["exact_evidence_id_1", "exact_evidence_id_2"],
  "limitations": ["Clear caveat on causality or evidence scope"]
}"""


class EvidenceFusionEngine:
    """
    Orchestrates Grounded Evidence Fusion using Nemotron (OpenRouter).
    Enforces three-layer evidence model (Fact, Signal, Interpretation),
    grounding validation, and deterministic fallback.
    """

    def __init__(self, client: Optional[OpenAI] = None):
        self.api_key = getattr(settings, "OPENROUTER_API_KEY", None)
        self.base_url = getattr(settings, "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        self.model = getattr(settings, "FINANCIAL_INTELLIGENCE_MODEL", "nvidia/nemotron-3-super-120b-a12b:free")
        self.reasoning_enabled = getattr(settings, "NEMOTRON_REASONING_ENABLED", True)

        self.client = client
        if not self.client and self.is_configured:
            self.client = OpenAI(base_url=self.base_url, api_key=self.api_key)

    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and self.api_key.strip())

    def _extract_json_block(self, raw_text: str) -> str:
        cleaned = raw_text.strip()
        if "```json" in cleaned:
            cleaned = cleaned.split("```json")[1].split("```")[0].strip()
        elif "```" in cleaned:
            cleaned = cleaned.split("```")[1].split("```")[0].strip()
        return cleaned

    def _build_fallback_insight(
        self,
        bundle: GroundedEvidenceBundle,
        status: GroundingStatus,
        reason: str
    ) -> GroundedMerchantInsight:
        now = datetime.now(timezone.utc)
        return GroundedMerchantInsight(
            insight_type=InsightType.INSUFFICIENT_EXTERNAL_EVIDENCE,
            title=f"Financial Anomaly: {bundle.event_title}",
            summary=f"{bundle.event_summary}. {reason}",
            financial_facts=bundle.internal_facts,
            external_signals=[],
            interpretation="Internal financial facts remain verified, but automated AI market synthesis is currently unavailable or ungrounded.",
            grounding_status=status,
            evidence_references=[],
            limitations=[reason, "Financial truth and canonical records remain fully intact."],
            model_metadata={"provider": "deterministic_fallback", "model": self.model},
            generated_at=now
        )

    def generate_insight(self, bundle: GroundedEvidenceBundle) -> GroundedMerchantInsight:
        # Case 1: Empty external evidence -> Return INSUFFICIENT_EVIDENCE deterministically
        if not bundle.external_evidence or bundle.research_status == "NO_EVIDENCE":
            return self._build_fallback_insight(
                bundle,
                GroundingStatus.INSUFFICIENT_EVIDENCE,
                "External market research produced no relevant external evidence."
            )

        # Case 2: Unconfigured OpenRouter -> Return fallback
        if not self.is_configured or not self.client:
            return self._build_fallback_insight(
                bundle,
                GroundingStatus.AI_INSIGHT_UNAVAILABLE,
                "AI explanation provider is not configured in current environment."
            )

        # Prepare user prompt
        user_prompt = f"""EVIDENCE BUNDLE:
Event Type: {bundle.event_type}
Event Title: {bundle.event_title}
Summary: {bundle.event_summary}
Category / Subject: {bundle.category or 'General Operations'}
Operating Location: {bundle.operating_city or ''}, {bundle.operating_state or 'India'}
Research Status: {bundle.research_status}

INTERNAL FINANCIAL FACTS (Verified Canonical Records):
{json.dumps([f.model_dump(mode='json') for f in bundle.internal_facts], indent=2)}

EXTERNAL MARKET SIGNALS (Retrieved Evidence):
{json.dumps([e.model_dump(mode='json') for e in bundle.external_evidence], indent=2)}

Synthesize these into a structured merchant explanation according to the rules."""

        extra_body = {}
        if self.reasoning_enabled:
            extra_body["reasoning"] = {"enabled": True}

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": FUSION_SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.1,
                extra_body=extra_body if extra_body else None
            )

            if not response.choices or not response.choices[0].message:
                return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, "Empty response from AI provider.")

            content = response.choices[0].message.content
            if not content or not content.strip():
                return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, "AI response content was empty.")

            json_str = self._extract_json_block(content)
            data = json.loads(json_str)

            # Map raw JSON into GroundedMerchantInsight
            raw_ext_signals = data.get("external_signals", [])
            ext_signals = [GroundedEvidenceReference.model_validate(s) for s in raw_ext_signals]

            insight = GroundedMerchantInsight(
                insight_type=InsightType(data.get("insight_type", InsightType.EXPENSE_PRESSURE_EXPLAINED)),
                title=str(data.get("title", bundle.event_title)),
                summary=str(data.get("summary", bundle.event_summary)),
                financial_facts=bundle.internal_facts,
                external_signals=ext_signals,
                interpretation=str(data.get("interpretation", "")),
                grounding_status=GroundingStatus(data.get("grounding_status", GroundingStatus.POTENTIAL_CONNECTION)),
                evidence_references=data.get("evidence_references", []),
                limitations=data.get("limitations", []),
                model_metadata={"provider": "OpenRouter", "model": self.model},
                generated_at=datetime.now(timezone.utc)
            )

            # Run strict Grounding Validator
            is_valid, validation_errors = GroundingValidator.validate(insight, bundle)
            if not is_valid:
                logger.warning("Grounding validation failed for generated insight: %s", validation_errors)
                return self._build_fallback_insight(
                    bundle,
                    GroundingStatus.AI_INSIGHT_UNAVAILABLE,
                    f"Generated insight failed grounding validation: {'; '.join(validation_errors)}"
                )

            return insight

        except RateLimitError as exc:
            logger.warning("OpenRouter rate limit in evidence fusion: %s", str(exc))
            return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, "AI provider rate limit reached (HTTP 429).")
        except (APITimeoutError, APIConnectionError) as exc:
            logger.error("OpenRouter network error in evidence fusion: %s", str(exc))
            return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, "AI provider connection timed out.")
        except APIError as exc:
            logger.error("OpenRouter API error in evidence fusion: %s", str(exc))
            return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, "AI provider service error.")
        except json.JSONDecodeError as exc:
            logger.error("Failed to parse JSON response from Nemotron: %s", str(exc))
            return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, "AI provider returned malformed JSON.")
        except Exception as exc:
            logger.error("Unexpected error in EvidenceFusionEngine: %s", str(exc))
            return self._build_fallback_insight(bundle, GroundingStatus.AI_INSIGHT_UNAVAILABLE, f"Internal error during insight synthesis: {str(exc)}")
