from app.models.communication_action import CommunicationChannel
from app.infrastructure.communication.provider_interface import CommunicationProviderInterface
from app.infrastructure.communication.messaging_provider import WhatsAppMessagingProvider, SMSMessagingProvider

class CommunicationProviderFactory:
    @staticmethod
    def get_provider(channel: CommunicationChannel) -> CommunicationProviderInterface:
        if channel == CommunicationChannel.WHATSAPP:
            return WhatsAppMessagingProvider()
        elif channel == CommunicationChannel.SMS:
            return SMSMessagingProvider()
        else:
            raise ValueError(f"Unsupported channel: {channel}")
