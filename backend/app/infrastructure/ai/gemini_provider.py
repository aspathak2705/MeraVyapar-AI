import os
import json
import httpx
from typing import Optional, List, Set
from app.infrastructure.ai.provider_interface import FinancialIntelligenceProvider
from app.schemas.financial_context import (
    FinancialContextPackage,
    GroundedInsightResponse,
    InsightSourceReference,
    KeyFactItem
)
from app.core.config import settings
from app.core.logging import logger


class GeminiIntelligenceProvider(FinancialIntelligenceProvider):
    def __init__(self):
        self.api_key = getattr(settings, "GEMINI_API_KEY", None) or os.environ.get("GEMINI_API_KEY") or os.environ.get("LLM_API_KEY")

    @property
    def is_available(self) -> bool:
        return bool(self.api_key and self.api_key.strip())

    def _unavailable_response(self, reason: str = "AI Intelligence service is not configured yet.") -> GroundedInsightResponse:
        return GroundedInsightResponse(
            summary=reason,
            why_it_matters="Deterministic financial facts, memory graph, and attention events remain fully operational.",
            key_facts=[],
            suggested_actions=["Review available events and payment promises directly in the workspace."],
            limitations=["LLM provider key is not configured in current environment."],
            source_references=[],
            is_ai_generated=False,
            status="LLM_INTELLIGENCE_UNAVAILABLE"
        )

    def _sanitize_provenance(self, insight: GroundedInsightResponse, context_package: FinancialContextPackage) -> GroundedInsightResponse:
        valid_entity_ids: Set[str] = {
            src.entity_id for src in context_package.provenance_sources
        }

        sanitized_refs: List[InsightSourceReference] = []
        for ref in insight.source_references:
            if ref.entity_id in valid_entity_ids:
                sanitized_refs.append(ref)

        insight.source_references = sanitized_refs if sanitized_refs else context_package.provenance_sources
        return insight

    def generate_event_explanation(self, context_package: FinancialContextPackage) -> GroundedInsightResponse:
        if not self.is_available:
            return self._unavailable_response()

        prompt = f"""
You are MeraVyapar AI, an explainable financial intelligence assistant for small merchants.
Provide a clear, grounded explanation for the following financial event using ONLY the supplied context package.

CRITICAL RULES:
1. Use ONLY facts provided in the JSON context package.
2. DO NOT calculate numbers, totals, or balances. All numbers are pre-calculated by system code.
3. DO NOT invent counterparties, amounts, due dates, or transactions.
4. Return ONLY valid JSON matching this exact structure:
{{
    "summary": "Short 1-2 sentence explanation of what happened",
    "why_it_matters": "Why this financial event requires merchant attention",
    "key_facts": [
        {{"label": "Fact Label", "value": "Fact Value", "source_reference": "entity_id"}}
    ],
    "suggested_actions": ["Action 1", "Action 2"],
    "limitations": ["Limitation if context is missing"],
    "source_references": [
        {{"entity_type": "type", "entity_id": "exact_id_from_context", "label": "label"}}
    ]
}}

CONTEXT PACKAGE:
{json.dumps(context_package.model_dump(mode="json"), indent=2)}
"""

        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={self.api_key}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"responseMimeType": "application/json"}
            }
            res = httpx.post(url, json=payload, timeout=10.0)
            if res.status_code == 200:
                data = res.json()
                text_content = data["candidates"][0]["content"]["parts"][0]["text"]
                insight_dict = json.loads(text_content)
                insight = GroundedInsightResponse.model_validate(insight_dict)
                return self._sanitize_provenance(insight, context_package)
            else:
                logger.warning(f"Gemini API returned status code {res.status_code}")
                return self._unavailable_response("AI Service responded with an error.")
        except Exception as e:
            logger.error(f"Error calling Gemini API: {str(e)}")
            return self._unavailable_response("AI Intelligence provider unavailable.")

    def answer_financial_question(self, context_package: FinancialContextPackage, question: str) -> GroundedInsightResponse:
        if not self.is_available:
            return self._unavailable_response()

        prompt = f"""
You are MeraVyapar AI, an explainable financial intelligence assistant for small merchants.
Answer the merchant's question: "{question}" using ONLY the supplied context package.

CRITICAL RULES:
1. Use ONLY facts provided in the JSON context package.
2. DO NOT calculate numbers, totals, or balances. All numbers are pre-calculated by system code.
3. DO NOT invent counterparties, amounts, due dates, or transactions.
4. Return ONLY valid JSON matching this exact structure:
{{
    "summary": "Short answer to the question",
    "why_it_matters": "Business context",
    "key_facts": [
        {{"label": "Fact Label", "value": "Fact Value", "source_reference": "entity_id"}}
    ],
    "suggested_actions": ["Suggested next step"],
    "limitations": ["Scope limitation"],
    "source_references": [
        {{"entity_type": "type", "entity_id": "exact_id_from_context", "label": "label"}}
    ]
}}

CONTEXT PACKAGE:
{json.dumps(context_package.model_dump(mode="json"), indent=2)}
"""

        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={self.api_key}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"responseMimeType": "application/json"}
            }
            res = httpx.post(url, json=payload, timeout=10.0)
            if res.status_code == 200:
                data = res.json()
                text_content = data["candidates"][0]["content"]["parts"][0]["text"]
                insight_dict = json.loads(text_content)
                insight = GroundedInsightResponse.model_validate(insight_dict)
                return self._sanitize_provenance(insight, context_package)
            else:
                return self._unavailable_response("AI Service responded with an error.")
        except Exception as e:
            logger.error(f"Error calling Gemini API: {str(e)}")
            return self._unavailable_response("AI Intelligence provider unavailable.")
