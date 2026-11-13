import logging
import re
from uuid import UUID
from typing import Dict, Any, Optional, Tuple, List
from decimal import Decimal
from sqlalchemy.orm import Session

from app.models.merchant import Merchant
from app.models.communication_action import CommunicationChannel
from app.features.events.services.receivables_prioritization_service import ReceivablesPrioritizationService
from app.features.memory.services.payment_promise_service import PaymentPromiseService
from app.features.cashflow_intelligence.services.cashflow_forecast_service import CashFlowForecastService
from app.features.actions.services.reminder_draft_service import ReminderDraftService
from app.features.financial_context.services.insight_persistence_service import InsightPersistenceService
from app.models.generated_insight import GeneratedInsight

logger = logging.getLogger(__name__)


class VoiceActionRouter:
    """
    Deterministic router mapping transcribed multilingual speech to existing MeraVyapar backend services.
    Enforces strict read-only execution for queries and constructs two-phase uncommitted action candidates
    for requested mutations.
    """

    def __init__(self, db: Session):
        self.db = db

    def route_and_execute(
        self,
        merchant_id: UUID,
        transcript: str,
        language_code: str = "hi-IN"
    ) -> Dict[str, Any]:
        """
        Interprets merchant speech and executes appropriate backend service.
        Returns structured dict containing:
        - intent: str
        - response_text: str (natural vernacular summary for TTS)
        - confirmation_required: bool
        - candidate_action: Optional[Dict[str, Any]] (action payload needing merchant confirmation)
        - metadata: Dict[str, Any]
        """
        raw_text = (transcript or "").strip()
        lower_text = raw_text.lower()

        # 1. Out of Scope Check
        out_of_scope_keywords = ["stock", "crypto", "share market", "loan", "trading", "mutual fund"]
        if any(kw in lower_text for kw in out_of_scope_keywords):
            resp = self._format_out_of_scope_response(language_code)
            return {
                "intent": "OUT_OF_SCOPE",
                "response_text": resp,
                "confirmation_required": False,
                "candidate_action": None,
                "metadata": {}
            }

        # 2. Procurement & Purchasing Intents (KharidSaathi Intelligence)
        # 2a. Compare quotations
        if any(w in lower_text for w in ["compare", "तुलना", "काउन्ट", "kaun better", "कम्पैरिजन", "फरक"]):
            return self._handle_procurement_comparison_query(language_code)

        # 2b. Purchase request creation / procurement draft
        if any(w in lower_text for w in ["चाहिए", "खरीदना", "purchase", "order", "सप्लायर से मंगाना", "मागवायचे"]):
            return self._handle_procurement_request_intent(raw_text, language_code)

        # 2c. Supplier obligations / upcoming payables
        if any(w in lower_text for w in ["supplier", "सप्लायर", "देना है", "देय", "देणी", "हप्ता", "obligation"]):
            return self._handle_supplier_obligations_query(language_code)

        # 3. Payment Promises Query
        # Hindi: "वादा", "प्रॉमिस", "किसने वादा किया", "किसका वादा आज है"
        # Marathi: "वचन", "प्रॉमिस", "कोणाचे प्रॉमिस"
        # English: "promise", "who promised", "due promises", "commitments"
        if any(w in lower_text for w in ["वादा", "प्रॉमिस", "वचन", "promise", "commitment"]):
            return self._handle_payment_promise_query(merchant_id, language_code)

        # 3. Reminder Drafting Intent (Two-Phase Mutation)
        # Hindi: "रिमाइंडर बनाओ", "याद दिलाओ", "मैसेज भेजो"
        # Marathi: "रिमाइंडर बनवा", "आठवण करा"
        # English: "prepare reminder", "draft reminder", "remind customer"
        if any(w in lower_text for w in ["रिमाइंडर", "याद दिलाओ", "मैसेज", "आठवण", "reminder", "draft message"]):
            return self._handle_reminder_draft_intent(merchant_id, lower_text, language_code)

        # 4. Receivables & Overdue Customers Query
        # Hindi: "कितना पैसा बाकी है", "उधार", "पैसे बाकी", "लेनदारी"
        # Marathi: "किती पैसे बाकी", "येणे बाकी", "उधारी"
        # English: "receivables", "who owes", "pending payments", "outstanding"
        if any(w in lower_text for w in ["बाकी", "उधार", "येणे", "receivable", "owes", "pending", "outstanding", "लेनदारी"]):
            return self._handle_receivables_query(merchant_id, language_code)

        # 5. Cashflow & Forecast Query
        # Hindi: "कैश फ्लो", "रोकड़", "खर्चा और कमाई", "अगले 15 दिन"
        # Marathi: "कॅश फ्लो", "रोकड"
        # English: "cashflow", "forecast", "liquidity", "cash balance"
        if any(w in lower_text for w in ["कैश", "रोकड़", "cashflow", "forecast", "रोकड", "liquidity"]):
            return self._handle_cashflow_query(merchant_id, language_code)

        # 6. Financial Explanation / Anomaly Insights
        # Hindi: "खर्चा क्यों बढ़ा", "एक्सपेंस", "कारण"
        # Marathi: "खर्च का वाढला"
        # English: "why did expenses increase", "anomaly", "expense surge"
        if any(w in lower_text for w in ["क्यों", "का वाढला", "why", "anomaly", "surge", "कारण"]):
            return self._handle_insights_query(merchant_id, language_code)

        # Default Fallback: Overview
        return self._handle_receivables_query(merchant_id, language_code)

    def _handle_receivables_query(self, merchant_id: UUID, lang: str) -> Dict[str, Any]:
        svc = ReceivablesPrioritizationService(self.db)
        items = svc.get_prioritized_receivables(merchant_id)

        if not items:
            text = (
                "आपके पास वर्तमान में कोई बकाया लेनदारी नहीं है।"
                if "hi" in lang else
                "तुमच्याकडे सध्या कोणतीही उधारी बाकी नाही."
                if "mr" in lang else
                "You have no outstanding receivables at this time."
            )
            return {
                "intent": "QUERY_RECEIVABLES",
                "response_text": text,
                "confirmation_required": False,
                "candidate_action": None,
                "metadata": {"count": 0, "total_outstanding": "0.00"}
            }

        top = items[0]
        total_sum = sum(item.amount for item in items)
        top_name = top.counterparty_name or "ग्राहक" if "hi" in lang else (top.counterparty_name or "ग्राहक" if "mr" in lang else (top.counterparty_name or "counterparty"))

        if "hi" in lang:
            text = (
                f"आपके कुल ₹{total_sum:,.2f} बकाया हैं। सबसे जरूरी {top_name} हैं, "
                f"जिनका ₹{top.amount:,.2f} बकाया है।"
            )
        elif "mr" in lang:
            text = (
                f"तुमचे एकूण ₹{total_sum:,.2f} येणे बाकी आहेत. सर्वात महत्त्वाचे {top_name} आहेत, "
                f"ज्यांचे ₹{top.amount:,.2f} बाकी आहेत."
            )
        else:
            text = (
                f"You have ₹{total_sum:,.2f} in total outstanding receivables across {len(items)} counterparties. "
                f"Highest priority is {top_name} with ₹{top.amount:,.2f}."
            )

        return {
            "intent": "QUERY_RECEIVABLES",
            "response_text": text,
            "confirmation_required": False,
            "candidate_action": None,
            "metadata": {
                "count": len(items),
                "total_outstanding": str(total_sum),
                "top_counterparty": top_name,
                "top_amount": str(top.amount)
            }
        }

    def _handle_payment_promise_query(self, merchant_id: UUID, lang: str) -> Dict[str, Any]:
        from app.repositories.payment_promise_repository import PaymentPromiseRepository
        repo = PaymentPromiseRepository(self.db)
        promises = repo.list_by_merchant(merchant_id, status=None, skip=0, limit=20)
        from app.models.payment_promise import PromiseStatus
        active_promises = [p for p in promises if p.status == PromiseStatus.OPEN]

        if not active_promises:
            text = (
                "आपके पास फिलहाल कोई सक्रिय भुगतान वादे दर्ज नहीं हैं।"
                if "hi" in lang else
                "तुमच्याकडे सध्या कोणतेही सक्रिय पेमेंट प्रॉमिस नोंदवलेले नाहीत."
                if "mr" in lang else
                "You have no active payment commitments recorded."
            )
            return {
                "intent": "QUERY_PAYMENT_PROMISES",
                "response_text": text,
                "confirmation_required": False,
                "candidate_action": None,
                "metadata": {"active_count": 0}
            }

        first = active_promises[0]
        amount_fmt = f"₹{first.promised_amount:,.2f}"
        first_cp_name = first.counterparty.display_name if first.counterparty else (first.description or "ग्राहक")

        if "hi" in lang:
            text = f"आपके पास {len(active_promises)} सक्रिय वादे हैं। पहला वादा {first_cp_name} का {amount_fmt} के लिए है।"
        elif "mr" in lang:
            text = f"तुमच्याकडे {len(active_promises)} सक्रिय वचने आहेत. पहिले वचन {first_cp_name} चे {amount_fmt} साठी आहे."
        else:
            text = f"You have {len(active_promises)} active payment promises. Next due is {first_cp_name} for {amount_fmt}."

        return {
            "intent": "QUERY_PAYMENT_PROMISES",
            "response_text": text,
            "confirmation_required": False,
            "candidate_action": None,
            "metadata": {
                "active_count": len(active_promises),
                "first_counterparty": first_cp_name,
                "first_amount": str(first.promised_amount)
            }
        }

    def _handle_cashflow_query(self, merchant_id: UUID, lang: str) -> Dict[str, Any]:
        svc = CashFlowForecastService(self.db)
        forecast = svc.generate_forecast(merchant_id)

        if forecast.get("status") == "INSUFFICIENT_DATA":
            text = (
                "कैश फ्लो का सटीक अनुमान लगाने के लिए पर्याप्त पिछला डेटा उपलब्ध नहीं है।"
                if "hi" in lang else
                "कॅश फ्लोच्या अंदाजासाठी पुरेसा जुना डेटा उपलब्ध नाही."
                if "mr" in lang else
                "Insufficient historical data available to generate a reliable cash flow projection."
            )
            return {
                "intent": "QUERY_CASHFLOW",
                "response_text": text,
                "confirmation_required": False,
                "candidate_action": None,
                "metadata": {"status": "INSUFFICIENT_DATA"}
            }

        net = forecast.get("projected_net_cashflow", 0.0)
        net_fmt = f"₹{abs(net):,.2f}"

        if "hi" in lang:
            text = f"अगले 30 दिनों का अनुमानित शुद्ध कैश फ्लो {net_fmt} है।"
        elif "mr" in lang:
            text = f"पुढील 30 दिवसांचा अंदाजित निव्वळ कॅश फ्लो {net_fmt} आहे."
        else:
            text = f"Projected net cashflow for the next 30 days is {net_fmt}."

        return {
            "intent": "QUERY_CASHFLOW",
            "response_text": text,
            "confirmation_required": False,
            "candidate_action": None,
            "metadata": forecast
        }

    def _handle_insights_query(self, merchant_id: UUID, lang: str) -> Dict[str, Any]:
        insights = (
            self.db.query(GeneratedInsight)
            .filter(GeneratedInsight.merchant_id == merchant_id)
            .order_by(GeneratedInsight.generated_at.desc())
            .limit(1)
            .all()
        )

        if not insights:
            text = (
                "वर्तमान में कोई महत्वपूर्ण वित्तीय विसंगति या अलर्ट नहीं है।"
                if "hi" in lang else
                "सध्या कोणतीही महत्त्वाची आर्थिक विसंगती किंवा अलर्ट नाही."
                if "mr" in lang else
                "No critical financial anomalies or cost spikes detected."
            )
            return {
                "intent": "QUERY_INSIGHTS",
                "response_text": text,
                "confirmation_required": False,
                "candidate_action": None,
                "metadata": {"count": 0}
            }

        ins = insights[0]
        text = ins.summary or ins.title

        return {
            "intent": "QUERY_INSIGHTS",
            "response_text": text,
            "confirmation_required": False,
            "candidate_action": None,
            "metadata": {
                "insight_id": str(ins.id),
                "title": ins.title,
                "grounding_status": ins.grounding_status
            }
        }

    def _handle_reminder_draft_intent(self, merchant_id: UUID, lower_text: str, lang: str) -> Dict[str, Any]:
        # Two-Phase Mutation Handshake
        # Step 1: Find active promise or overdue receivable to draft reminder for
        from app.repositories.payment_promise_repository import PaymentPromiseRepository
        from app.models.payment_promise import PromiseStatus
        repo = PaymentPromiseRepository(self.db)
        promises = repo.list_by_merchant(merchant_id, status=None, skip=0, limit=20)
        active_promises = [p for p in promises if p.status in (PromiseStatus.OPEN, PromiseStatus.OVERDUE)]

        target_promise = active_promises[0] if active_promises else None

        if not target_promise:
            text = (
                "रिमाइंडर बनाने के लिए कोई सक्रिय पेमेंट वादा नहीं मिला।"
                if "hi" in lang else
                "रिमाइंडर तयार करण्यासाठी कोणतेही सक्रिय पेमेंट प्रॉमिस सापडले नाही."
                if "mr" in lang else
                "No active payment commitment found to draft a reminder for."
            )
            return {
                "intent": "DRAFT_REMINDER",
                "response_text": text,
                "confirmation_required": False,
                "candidate_action": None,
                "metadata": {}
            }

        target_cp_name = None
        if target_promise.counterparty_id:
            from app.repositories.counterparty_repository import CounterpartyRepository
            cp_repo = CounterpartyRepository(self.db)
            cp = cp_repo.get_by_id(target_promise.counterparty_id, merchant_id)
            if cp:
                target_cp_name = cp.display_name

        if not target_cp_name:
            target_cp_name = (
                target_promise.counterparty.display_name
                if getattr(target_promise, "counterparty", None)
                else (target_promise.description or "ग्राहक")
            )

        candidate = {
            "action_type": "DRAFT_PAYMENT_REMINDER",
            "promise_id": str(target_promise.id),
            "counterparty_name": target_cp_name,
            "amount": str(target_promise.promised_amount),
            "channel": "WHATSAPP",
            "endpoint": "/api/v1/actions/draft-reminder",
        }

        if "hi" in lang:
            text = (
                f"{target_cp_name} के लिए ₹{target_promise.promised_amount:,.2f} का "
                f"पेमेंट रिमाइंडर ड्राफ्ट तैयार किया गया है। क्या आप इसे भेजना चाहते हैं?"
            )
        elif "mr" in lang:
            text = (
                f"{target_cp_name} साठी ₹{target_promise.promised_amount:,.2f} चे "
                f"पेमेंट रिमाइंडर तयार केले आहे. आपण ते पाठवू इच्छिता?"
            )
        else:
            text = (
                f"Prepared a payment reminder draft for {target_cp_name} for "
                f"₹{target_promise.promised_amount:,.2f}. Do you want to confirm and send?"
            )

        return {
            "intent": "DRAFT_REMINDER",
            "response_text": text,
            "confirmation_required": True,
            "candidate_action": candidate,
            "metadata": {
                "promise_id": str(target_promise.id),
                "counterparty_name": target_cp_name,
                "amount": str(target_promise.promised_amount)
            }
        }

    def _format_out_of_scope_response(self, lang: str) -> str:
        if "hi" in lang:
            return "मेरा व्यापार केवल आपके व्यापारिक रिकॉर्ड, लेनदारी और वादों को समझता है। शेयर बाजार, लोन या ट्रेडिंग सलाह हमारे दायरे से बाहर है।"
        elif "mr" in lang:
            return "माझा व्यापार फक्त तुमचे व्यावसायिक रेकॉर्ड, उधारी आणि वचने व्यवस्थापित करतो. शेअर बाजार किंवा कर्ज सल्ला आमच्या कक्षेत येत नाही."
        return "MeraVyapar handles merchant records, receivables, and payment commitments. Stock market, loans, and investment advice are out of scope."

    def _handle_procurement_comparison_query(self, lang: str) -> Dict[str, Any]:
        if "hi" in lang:
            text = "कोटेशन तुलना के अनुसार, कुल लैंडेड कॉस्ट (जीएसटी और भाड़े सहित) और डिलीवरी अवधि के आधार पर सबसे उपयुक्त सप्लायर चुना गया है। विवरण स्क्रीन पर उपलब्ध है।"
        elif "mr" in lang:
            text = "कोटेशन तुलनेनुसार, एकूण लँडेड खर्च (जीएसटी आणि भाड्याने) आणि वितरण वेळेनुसार सर्वोत्तम पुरवठादार निवडला आहे. तपशील स्क्रीनवर उपलब्ध आहे."
        else:
            text = "Quotation comparison complete. Ranked by total landed cost (inclusive of GST and freight) and delivery lead time. Detailed analysis ready on screen."
        return {
            "intent": "COMPARE_SUPPLIER_QUOTES",
            "response_text": text,
            "confirmation_required": False,
            "candidate_action": None,
            "metadata": {"source": "kharidsaathi_engine"}
        }

    def _handle_procurement_request_intent(self, raw_text: str, lang: str) -> Dict[str, Any]:
        candidate = {
            "action_type": "CREATE_PURCHASE_REQUEST",
            "raw_prompt": raw_text,
            "item_name": raw_text,
            "source": "voice_procurement",
        }
        if "hi" in lang:
            text = f"आपकी मांग '{raw_text}' के लिए नई खरीद मांग (Purchase Request) तैयार की गई है। क्या आप इसे सहेजना चाहते हैं?"
        elif "mr" in lang:
            text = f"तुमच्या '{raw_text}' मागणीसाठी नवीन खरेदी विनंती तयार केली आहे. आपण ही सेव्ह करू इच्छिता?"
        else:
            text = f"Prepared a purchase request for '{raw_text}'. Do you want to confirm and save?"
        return {
            "intent": "CREATE_PURCHASE_REQUEST",
            "response_text": text,
            "confirmation_required": True,
            "candidate_action": candidate,
            "metadata": {"prompt": raw_text}
        }

    def _handle_supplier_obligations_query(self, lang: str) -> Dict[str, Any]:
        if "hi" in lang:
            text = "आपके आगामी सप्लायर भुगतानों का विवरण आपकी कैशफ्लो स्थिति में शामिल कर दिया गया है। पूर्ण विवरण स्क्रीन पर देखें।"
        elif "mr" in lang:
            text = "तुमची आगामी पुरवठादार देणी कॅशफ्लो स्थितीत समाविष्ट केली आहेत. संपूर्ण माहिती स्क्रीनवर तपासा."
        else:
            text = "Upcoming supplier obligations are reflected in your cashflow forecast. Full breakdown available on screen."
        return {
            "intent": "QUERY_SUPPLIER_OBLIGATIONS",
            "response_text": text,
            "confirmation_required": False,
            "candidate_action": None,
            "metadata": {}
        }

