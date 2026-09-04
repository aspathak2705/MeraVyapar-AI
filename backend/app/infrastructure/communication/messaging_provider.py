from typing import Dict, Any, Optional
import os
import uuid

from app.infrastructure.communication.provider_interface import CommunicationProviderInterface


class WhatsAppMessagingProvider(CommunicationProviderInterface):
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("WHATSAPP_API_KEY")

    def send_message(
        self,
        recipient_info: Dict[str, Any],
        content: str,
        idempotency_key: str
    ) -> Dict[str, Any]:
        if not self.api_key:
            return {
                "provider_message_id": "",
                "status": "FAILED",
                "raw_response": {},
                "error_code": "COMMUNICATION_PROVIDER_UNAVAILABLE",
                "error_message": "WhatsApp provider API key missing"
            }

        # Simulated dispatch success when provider configured
        return {
            "provider_message_id": f"wa_msg_{uuid.uuid4().hex[:12]}",
            "status": "SENT",
            "raw_response": {"provider": "whatsapp", "status": "delivered_to_gateway"},
            "error_code": None,
            "error_message": None
        }


class SMSMessagingProvider(CommunicationProviderInterface):
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("SMS_API_KEY")

    def send_message(
        self,
        recipient_info: Dict[str, Any],
        content: str,
        idempotency_key: str
    ) -> Dict[str, Any]:
        if not self.api_key:
            return {
                "provider_message_id": "",
                "status": "FAILED",
                "raw_response": {},
                "error_code": "COMMUNICATION_PROVIDER_UNAVAILABLE",
                "error_message": "SMS provider API key missing"
            }

        return {
            "provider_message_id": f"sms_msg_{uuid.uuid4().hex[:12]}",
            "status": "SENT",
            "raw_response": {"provider": "sms", "status": "delivered_to_gateway"},
            "error_code": None,
            "error_message": None
        }
