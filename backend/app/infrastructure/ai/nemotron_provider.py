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
        self.model = getattr(settings, "FINANCIAL_INTELLIGENCE_MODEL", "nvidia/nemotron-3.5-lightning:free")
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

    DEVANAGARI_DIGITS = {
        '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
        '५': '5', '६': '6', '७': '7', '८': '8', '९': '9'
    }

    def _normalize_digits(self, text: str) -> str:
        for dev, arab in self.DEVANAGARI_DIGITS.items():
            text = text.replace(dev, arab)
        return text

    def _build_language_instruction(self, target_language: str) -> str:
        lang = (target_language or "en").lower().strip()
        if lang == "hi":
            return """LANGUAGE DIRECTIVE:
You MUST generate all descriptive human-readable text (summary, why_it_matters, key_facts labels, suggested_actions, limitations) in natural, fluent, authentic Hindi (हिंदी).
Maintain all numeric figures, currency symbols (₹), and source reference IDs exactly as provided without modification.
Always format numbers using standard Arabic digits (0-9) e.g. ₹25,000, 1500."""
        elif lang == "mr":
            return """LANGUAGE DIRECTIVE:
You MUST generate all descriptive human-readable text (summary, why_it_matters, key_facts labels, suggested_actions, limitations) in natural, fluent, authentic Marathi (मराठी).
Maintain all numeric figures, currency symbols (₹), and source reference IDs exactly as provided without modification.
Always format numbers using standard Arabic digits (0-9) e.g. ₹25,000, 1500."""
        else:
            return """LANGUAGE DIRECTIVE:
Generate all descriptive text in clear, practical, merchant-friendly English."""

    def _make_error_response(self, status: str, summary: str, limitation: str, target_language: str = "en") -> GroundedInsightResponse:
        why = "Deterministic financial facts, memory graph, and attention events remain fully operational."
        actions = ["Review available events and payment promises directly in the workspace."]
        lang = (target_language or "en").lower().strip()
        if lang == "hi":
            why = "स्थानीय वित्तीय तथ्य, मेमोरी ग्राफ़ और इवेंट्स पूरी तरह सक्रिय हैं।"
            actions = ["कार्यक्षेत्र में उपलब्ध घटनाओं और भुगतान वादों की सीधे समीक्षा करें।"]
            if status == "LLM_INTELLIGENCE_UNAVAILABLE":
                summary = "वर्तमान वातावरण में एआई इंटेलिजेंस सेवा कॉन्फ़िगर नहीं है।"
            elif status == "LLM_RATE_LIMITED":
                summary = "वित्तीय एआई सेवा व्यस्त है। कृपया थोड़ी देर बाद पुनः प्रयास करें।"
        elif lang == "mr":
            why = "स्थानिक आर्थिक तथ्य, मेमरी आलेख आणि इव्हेंट्स पूर्णपणे कार्यरत आहेत."
            actions = ["कार्यक्षेत्रात उपलब्ध घटना आणि पेमेंट वचनांचे थेट पुनरावलोकन करा."]
            if status == "LLM_INTELLIGENCE_UNAVAILABLE":
                summary = "सध्याच्या वातावरणात एआय इंटेलिजन्स सेवा कॉन्फिगर केलेली नाही."
            elif status == "LLM_RATE_LIMITED":
                summary = "आर्थिक एआय सेवा व्यस्त आहे. कृपया थोड्या वेळाने पुन्हा प्रयत्न करा."

        return GroundedInsightResponse(
            summary=summary,
            why_it_matters=why,
            key_facts=[],
            suggested_actions=actions,
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

    def _validate_amounts(self, insight: GroundedInsightResponse, context_package: FinancialContextPackage, target_language: str = "en") -> GroundedInsightResponse:
        """
        Extract numerical monetary amounts from context and ensure model doesn't invent new numbers in key_facts or summary.
        If a fabricated amount is detected, invalidate the response completely (LLM_RESPONSE_INVALID).
        """
        # Collect all numeric values present in context package (events, payment_promises, receivables, computed_metrics)
        context_str = json.dumps(context_package.model_dump(mode="json"))
        clean_context = re.sub(r'(?<=\d),(?=\d)', '', context_str)
        # Find monetary numbers in context
        context_numbers = set(re.findall(r'\b\d+(?:\.\d+)?\b', clean_context))

        # Check summary, why_it_matters, and key_facts for fabricated numbers
        all_text_to_check = [insight.summary, insight.why_it_matters] + [kf.value for kf in insight.key_facts]

        for text in all_text_to_check:
            clean_text = self._normalize_digits(text or "")
            clean_text = re.sub(r'(?<=\d),(?=\d)', '', clean_text)
            found_numbers = set(re.findall(r'\b\d+(?:\.\d+)?\b', clean_text))
            fabricated = [num for num in found_numbers if num not in context_numbers and float(num) > 0]
            if fabricated:
                logger.warning(f"Fabricated monetary amounts detected in model response: {fabricated}")
                return self._make_error_response(
                    status="LLM_RESPONSE_INVALID",
                    summary="AI response contained unverified numerical amounts.",
                    limitation="Model generated monetary amounts not present in verified context.",
                    target_language=target_language,
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

    def _call_openrouter_completion(self, system_prompt: str, user_prompt: str, target_language: str = "en") -> GroundedInsightResponse:
        if not self.is_available or not self.client:
            return self._make_error_response(
                status="LLM_INTELLIGENCE_UNAVAILABLE",
                summary="AI Intelligence service is not configured in current environment.",
                limitation="OPENROUTER_API_KEY is missing.",
                target_language=target_language,
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
                    limitation="Provider returned response without content choices.",
                    target_language=target_language,
                )

            content = response.choices[0].message.content
            if not content or not content.strip():
                return self._make_error_response(
                    status="LLM_RESPONSE_INVALID",
                    summary="Empty text content returned by AI provider.",
                    limitation="Model output content was empty.",
                    target_language=target_language,
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
                limitation="OpenRouter API rate limit reached (HTTP 429).",
                target_language=target_language,
            )
        except (APITimeoutError, APIConnectionError) as e:
            logger.error(f"OpenRouter connection/timeout error: {str(e)}")
            return self._make_error_response(
                status="LLM_PROVIDER_ERROR",
                summary="AI Intelligence provider network timeout.",
                limitation="Network request timed out or connection failed.",
                target_language=target_language,
            )
        except APIError as e:
            logger.error(f"OpenRouter API error: {str(e)}")
            return self._make_error_response(
                status="LLM_PROVIDER_ERROR",
                summary="AI Service responded with an error.",
                limitation=f"OpenRouter API error (code: {getattr(e, 'status_code', 'unknown')}).",
                target_language=target_language,
            )
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON from model output: {str(e)}")
            return self._make_error_response(
                status="LLM_RESPONSE_INVALID",
                summary="Invalid structured JSON response from AI provider.",
                limitation="Model response failed JSON parsing.",
                target_language=target_language,
            )
        except Exception as e:
            logger.error(f"Unexpected error calling OpenRouter Nemotron API: {str(e)}")
            return self._make_error_response(
                status="LLM_PROVIDER_ERROR",
                summary="AI Intelligence provider unavailable.",
                limitation="Unexpected error encountered.",
                target_language=target_language,
            )

    def generate_event_explanation(self, context_package: FinancialContextPackage, target_language: str = "en") -> GroundedInsightResponse:
        lang_directive = self._build_language_instruction(target_language)
        system_prompt = f"""You are the explanation layer of a financial intelligence system.
You receive verified and deterministic financial context.
You must only explain facts explicitly present in the supplied context.

{lang_directive}

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

        insight = self._call_openrouter_completion(system_prompt, user_prompt, target_language=target_language)
        if insight.status == "CURRENT":
            insight = self._sanitize_provenance(insight, context_package)
            insight = self._validate_amounts(insight, context_package, target_language=target_language)
        return insight

    def answer_financial_question(self, context_package: FinancialContextPackage, question: str, target_language: str = "en") -> GroundedInsightResponse:
        lang_directive = self._build_language_instruction(target_language)
        system_prompt = f"""You are the explanation layer of a financial intelligence system.
You receive verified deterministic financial context and external market signals.
You must only explain facts explicitly present in the supplied context.

{lang_directive}

You must not:
- invent financial information or market claims
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

When market signals (market_signals) are present in the context, relate them to the merchant's financial metrics (computed_metrics) and explain their business implications (e.g. procurement cost variation vs available cash or payables) using only verified numbers and cited sources from the context package.
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

        insight = self._call_openrouter_completion(system_prompt, user_prompt, target_language=target_language)
        if insight.status == "CURRENT":
            insight = self._sanitize_provenance(insight, context_package)
            insight = self._validate_amounts(insight, context_package, target_language=target_language)
        return insight
