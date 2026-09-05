from app.models.communication_action import CommunicationChannel
from app.infrastructure.communication.provider_interface import CommunicationProviderInterface
from app.infrastructure.communication.messaging_provider import (
    SimulatedWhatsAppProvider,
    SimulatedSMSProvider,
    ProductionWhatsAppProvider,
    ProductionSMSProvider,
    UnavailableCommunicationProvider
)
from app.core.config import settings


class CommunicationProviderFactory:
    @staticmethod
    def get_provider(channel: CommunicationChannel, force_fail: bool = False) -> CommunicationProviderInterface:
        mode = getattr(settings, "EXTERNAL_PROVIDER_MODE", "simulation").lower()

        if mode == "disabled":
            return UnavailableCommunicationProvider()

        if mode == "production":
            if channel == CommunicationChannel.WHATSAPP:
                return ProductionWhatsAppProvider()
            elif channel == CommunicationChannel.SMS:
                return ProductionSMSProvider()
            else:
                return UnavailableCommunicationProvider()

        # Default / Simulation mode
        if channel == CommunicationChannel.WHATSAPP:
            return SimulatedWhatsAppProvider(should_fail=force_fail)
        elif channel == CommunicationChannel.SMS:
            return SimulatedSMSProvider(should_fail=force_fail)
        else:
            return SimulatedWhatsAppProvider(should_fail=force_fail)

