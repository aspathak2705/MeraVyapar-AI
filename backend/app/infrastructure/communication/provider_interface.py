from abc import ABC, abstractmethod
from typing import Dict, Any, Optional

class CommunicationProviderInterface(ABC):
    @abstractmethod
    def send_message(
        self,
        recipient_info: Dict[str, Any],
        content: str,
        idempotency_key: str
    ) -> Dict[str, Any]:
        """
        Sends message to target provider.
        Must return dict containing:
        - provider_message_id: str
        - status: str ("SENT" or "FAILED")
        - raw_response: Dict[str, Any]
        - error_code: Optional[str]
        - error_message: Optional[str]
        """
        pass
