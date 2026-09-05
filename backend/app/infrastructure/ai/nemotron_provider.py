import os
import json
import re
from typing import Optional, List, Set, Dict, Any
from openai import OpenAI, RateLimitError, APIError, APIConnectionError, APITimeoutError
from app.infrastructure.ai.provider_interface import FinancialIntelligenceProvider
from app.schemas.financial_context import (
    FinancialContextPackage,
    GroundedInsightResponse,
    InsightSourceReference,
    KeyFactItem
)
from app.core.config import settings
from app.core.logging import logger


class NemotronIntelligenceProvider(FinancialIntelligenceProvider):
    def __init__(self):
        self.api_key = getattr(settings, "OPENROUTER_API_KEY", None) or os.environ.get("OPENROUTER_API_KEY")
        self.base_url = getattr(settings, "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        self.model = getattr(settings, "FINANCIAL_INTELLIGENCE_MODEL", "nvidia/nemotron-3-super-120b-a12b:free")
        self.reasoning_enabled = getattr(settings, "NEMOTRON_REASONING_ENABLED", True)

        self.client: Optional[OpenAI] = None
        if self.is_available:
            self.client = OpenAI(
                base_url=self.base_url,
                api_key=self.api_key,
            )

    @property
    def is_available(self) -> bool:
        return bool(self.api_key and self.api_key.strip())

    def _make_error_response(self, status: str, summary: str, limitation: str) -> GroundedInsightResponse:
        return GroundedInsightResponse(
            summary=summary,
            why_it_matters="Deterministic financial facts, memory graph, and attention events remain fully operational.",
            key_facts=[],
            suggested_actions=["Review available events and payment promises directly in the workspace."],
            limitations=[limitation],
            source_references=[],
            is_ai_generated=False,
            status=status
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

    def _validate_amounts(self, insight: GroundedInsightResponse, context_package: FinancialContextPackage) -> GroundedInsightResponse:
        """
        Extract numerical monetary amounts from context and ensure model doesn't invent new numbers in key_facts or summary.
        If a fabricated amount is detected, invalidate the response completely (LLM_RESPONSE_INVALID).
        """
        # Collect all numeric values present in context package (events, payment_promises, receivables, computed_metrics)
        context_str = json.dumps(context_package.model_dump(mode="json"))
        # Find monetary numbers in context
        context_numbers = set(re.findall(r'\b\d+(?:\.\d+)?\b', context_str))

        # Check summary, why_it_matters, and key_facts for fabricated numbers
        all_text_to_check = [insight.summary, insight.why_it_matters] + [kf.value for kf in insight.key_facts]

        for text in all_text_to_check:
            found_numbers = set(re.findall(r'\b\d+(?:\.\d+)?\b', text))
            fabricated = [num for num in found_numbers if num not in context_numbers and float(num) > 0]
            if fabricated:
                logger.warning(f"Fabricated monetary amounts detected in model response: {fabricated}")
                return self._make_error_response(
                    status="LLM_RESPONSE_INVALID",
                    summary="AI response contained unverified numerical amounts.",
                    limitation="Model generated monetary amounts not present in verified context."
                )

        return insight


    def _extract_json_block(self, raw_text: str) -> str:
        """Extracts JSON substring if enclosed in markdown code blocks."""
        cleaned = raw_text.strip()
        if "```json" in cleaned:
            cleaned = cleaned.split("```json")[1].split("```")[0].strip()
        elif "```" in cleaned:
            cleaned = cleaned.split("```")[1].split("```")[0].strip()
        return cleaned

    def _call_openrouter_completion(self, system_prompt: str, user_prompt: str) -> GroundedInsightResponse:
        if not self.is_available or not self.client:
            return self._make_error_response(
                status="LLM_INTELLIGENCE_UNAVAILABLE",
                summary="AI Intelligence service is not configured in current environment.",
                limitation="OPENROUTER_API_KEY is missing."
            )

        extra_body = {}
        if self.reasoning_enabled:
            extra_body["reasoning"] = {"enabled": True}

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.1,
                extra_body=extra_body if extra_body else None
            )

            if not response.choices or not response.choices[0].message:
                return self._make_error_response(
                    status="LLM_RESPONSE_INVALID",
                    summary="Empty model response received.",
                    limitation="Provider returned response without content choices."
                )

            content = response.choices[0].message.content
            if not content or not content.strip():
                return self._make_error_response(
                    status="LLM_RESPONSE_INVALID",
                    summary="Empty text content returned by AI provider.",
                    limitation="Model output content was empty."
                )

            json_str = self._extract_json_block(content)
            insight_dict = json.loads(json_str)
            insight = GroundedInsightResponse.model_validate(insight_dict)
            return insight

        except RateLimitError as e:
            logger.warning(f"OpenRouter rate limit hit (429): {str(e)}")
            return self._make_error_response(
                status="LLM_RATE_LIMITED",
                summary="Financial AI is temporarily busy. Please try again shortly.",
                limitation="OpenRouter API rate limit reached (HTTP 429)."
            )
        except (APITimeoutError, APIConnectionError) as e:
            logger.error(f"OpenRouter connection/timeout error: {str(e)}")
            return self._make_error_response(
                status="LLM_PROVIDER_ERROR",
                summary="AI Intelligence provider network timeout.",
                limitation="Network request timed out or connection failed."
            )
        except APIError as e:
            logger.error(f"OpenRouter API error: {str(e)}")
            return self._make_error_response(
                status="LLM_PROVIDER_ERROR",
                summary="AI Service responded with an error.",
                limitation=f"OpenRouter API error (code: {getattr(e, 'status_code', 'unknown')})."
            )
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON from model output: {str(e)}")
            return self._make_error_response(
                status="LLM_RESPONSE_INVALID",
                summary="Invalid structured JSON response from AI provider.",
                limitation="Model response failed JSON parsing."
            )
        except Exception as e:
            logger.error(f"Unexpected error calling OpenRouter Nemotron API: {str(e)}")
            return self._make_error_response(
                status="LLM_PROVIDER_ERROR",
                summary="AI Intelligence provider unavailable.",
                limitation="Unexpected error encountered."
            )

    def generate_event_explanation(self, context_package: FinancialContextPackage) -> GroundedInsightResponse:
        system_prompt = """You are the explanation layer of a financial intelligence system.
You receive verified and deterministic financial context.
You must only explain facts explicitly present in the supplied context.

You must not:
- invent financial information
- calculate new financial values
- infer missing values
- estimate probabilities
- create scores
- state synthetic or reference benchmark patterns (SYNTHETIC_REFERENCE_PATTERN) as observed merchant transaction facts
- provide investment advice
- recommend stocks
- recommend loans
- recommend crypto assets
- forecast revenue
- claim information not represented in the context

If the supplied context does not support an answer, clearly state that sufficient verified information is unavailable.
Use concise, practical language suitable for a small business merchant.
Return only the required structured JSON output."""

        user_prompt = f"""Provide a clear, grounded explanation for the financial event in this context using ONLY the supplied context package.

Return ONLY valid JSON matching this exact structure:
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
{json.dumps(context_package.model_dump(mode="json"), indent=2)}"""

        insight = self._call_openrouter_completion(system_prompt, user_prompt)
        if insight.status == "CURRENT":
            insight = self._sanitize_provenance(insight, context_package)
            insight = self._validate_amounts(insight, context_package)
        return insight

    def answer_financial_question(self, context_package: FinancialContextPackage, question: str) -> GroundedInsightResponse:
        system_prompt = """You are the explanation layer of a financial intelligence system.
You receive verified and deterministic financial context.
You must only explain facts explicitly present in the supplied context.

You must not:
- invent financial information
- calculate new financial values
- infer missing values
- estimate probabilities
- create scores
- provide investment advice
- recommend stocks
- recommend loans
- recommend crypto assets
- forecast revenue
- claim information not represented in the context

If the supplied context does not support an answer, clearly state that sufficient verified information is unavailable.
Use concise, practical language suitable for a small business merchant.
Return only the required structured JSON output."""

        user_prompt = f"""Answer the merchant's question: "{question}" using ONLY the supplied context package.

Return ONLY valid JSON matching this exact structure:
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
{json.dumps(context_package.model_dump(mode="json"), indent=2)}"""

        insight = self._call_openrouter_completion(system_prompt, user_prompt)
        if insight.status == "CURRENT":
            insight = self._sanitize_provenance(insight, context_package)
            insight = self._validate_amounts(insight, context_package)
        return insight
