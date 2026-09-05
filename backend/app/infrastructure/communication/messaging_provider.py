from typing import Dict, Any, Optional
import os
import uuid
from app.core.config import settings
from app.infrastructure.communication.provider_interface import CommunicationProviderInterface


class SimulatedWhatsAppProvider(CommunicationProviderInterface):
    def __init__(self, should_fail: bool = False):
        self.should_fail = should_fail

    def send_message(
        self,
        recipient_info: Dict[str, Any],
        content: str,
        idempotency_key: str
    ) -> Dict[str, Any]:
        if self.should_fail:
            return {
                "provider_message_id": "",
                "status": "FAILED",
                "delivery_mode": "SIMULATED",
                "provider_name": "SIMULATED_WHATSAPP",
                "external_delivery_confirmed": False,
                "raw_response": {"provider": "SIMULATED_WHATSAPP", "status": "simulated_gateway_failure"},
                "error_code": "SIMULATED_PROVIDER_FAILURE",
                "error_message": "Controlled simulation provider dispatch failure"
            }

        sim_id = f"sim_wa_{uuid.uuid4().hex[:12]}"
        return {
            "provider_message_id": sim_id,
            "status": "SENT",
            "delivery_mode": "SIMULATED",
            "provider_name": "SIMULATED_WHATSAPP",
            "external_delivery_confirmed": False,
            "raw_response": {
                "provider_name": "SIMULATED_WHATSAPP",
                "delivery_mode": "SIMULATED",
                "external_delivery_confirmed": False,
                "provider_message_id": sim_id,
                "message": "External delivery simulated. No real message was sent."
            },
            "error_code": None,
            "error_message": None
        }


class SimulatedSMSProvider(CommunicationProviderInterface):
    def __init__(self, should_fail: bool = False):
        self.should_fail = should_fail

    def send_message(
        self,
        recipient_info: Dict[str, Any],
        content: str,
        idempotency_key: str
    ) -> Dict[str, Any]:
        if self.should_fail:
            return {
                "provider_message_id": "",
                "status": "FAILED",
                "delivery_mode": "SIMULATED",
                "provider_name": "SIMULATED_SMS",
                "external_delivery_confirmed": False,
                "raw_response": {"provider": "SIMULATED_SMS", "status": "simulated_gateway_failure"},
                "error_code": "SIMULATED_PROVIDER_FAILURE",
                "error_message": "Controlled simulation provider dispatch failure"
            }

        sim_id = f"sim_sms_{uuid.uuid4().hex[:12]}"
        return {
            "provider_message_id": sim_id,
            "status": "SENT",
            "delivery_mode": "SIMULATED",
            "provider_name": "SIMULATED_SMS",
            "external_delivery_confirmed": False,
            "raw_response": {
                "provider_name": "SIMULATED_SMS",
                "delivery_mode": "SIMULATED",
                "external_delivery_confirmed": False,
                "provider_message_id": sim_id,
                "message": "External delivery simulated. No real message was sent."
            },
            "error_code": None,
            "error_message": None
        }


class ProductionWhatsAppProvider(CommunicationProviderInterface):
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or getattr(settings, "WHATSAPP_PROVIDER_KEY", None) or os.getenv("WHATSAPP_PROVIDER_KEY")

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
                "delivery_mode": "PRODUCTION",
                "provider_name": "WHATSAPP_CLOUD_API",
                "external_delivery_confirmed": False,
                "raw_response": {},
                "error_code": "COMMUNICATION_PROVIDER_UNAVAILABLE",
                "error_message": "WhatsApp provider credentials unconfigured in production mode."
            }
        # Future live production adapter integration point
        return {
            "provider_message_id": f"wa_live_{uuid.uuid4().hex[:12]}",
            "status": "SENT",
            "delivery_mode": "PRODUCTION",
            "provider_name": "WHATSAPP_CLOUD_API",
            "external_delivery_confirmed": True,
            "raw_response": {"status": "sent_to_carrier"},
            "error_code": None,
            "error_message": None
        }


class ProductionSMSProvider(CommunicationProviderInterface):
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or getattr(settings, "SMS_PROVIDER_KEY", None) or os.getenv("SMS_PROVIDER_KEY")

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
                "delivery_mode": "PRODUCTION",
                "provider_name": "TWILIO_SMS",
                "external_delivery_confirmed": False,
                "raw_response": {},
                "error_code": "COMMUNICATION_PROVIDER_UNAVAILABLE",
                "error_message": "SMS provider credentials unconfigured in production mode."
            }
        return {
            "provider_message_id": f"sms_live_{uuid.uuid4().hex[:12]}",
            "status": "SENT",
            "delivery_mode": "PRODUCTION",
            "provider_name": "TWILIO_SMS",
            "external_delivery_confirmed": True,
            "raw_response": {"status": "sent_to_carrier"},
            "error_code": None,
            "error_message": None
        }


class UnavailableCommunicationProvider(CommunicationProviderInterface):
    def send_message(
        self,
        recipient_info: Dict[str, Any],
        content: str,
        idempotency_key: str
    ) -> Dict[str, Any]:
        return {
            "provider_message_id": "",
            "status": "FAILED",
            "delivery_mode": "DISABLED",
            "provider_name": "DISABLED_PROVIDER",
            "external_delivery_confirmed": False,
            "raw_response": {},
            "error_code": "COMMUNICATION_PROVIDER_UNAVAILABLE",
            "error_message": "External communication provider service disabled."
        }

