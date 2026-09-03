from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, BinaryIO


class ObjectStorage(ABC):
    @abstractmethod
    def upload(self, file_obj: BinaryIO, object_key: str, content_type: str) -> str:
        """
        Uploads file object to storage and returns object key / reference.
        """
        pass

    @abstractmethod
    def get_metadata(self, object_key: str) -> Optional[Dict[str, Any]]:
        """
        Retrieves metadata for object key if present.
        """
        pass

    @abstractmethod
    def delete(self, object_key: str) -> bool:
        """
        Deletes object by object key.
        """
        pass
