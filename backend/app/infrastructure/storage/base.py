from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, BinaryIO
from dataclasses import dataclass
from datetime import datetime, timezone


class StorageError(Exception):
    """Base exception for all storage-level failures."""
    pass


class StorageValidationError(StorageError):
    """Raised when file fails validation (unsupported MIME, invalid signature, empty/oversized)."""
    pass


class StorageUnavailableError(StorageError):
    """Raised when the storage backend cannot be reached or fails to execute operation."""
    pass


class StorageNotFoundError(StorageError):
    """Raised when requested object key does not exist."""
    pass


@dataclass(frozen=True)
class StoredObjectMetadata:
    """Minimal immutable file metadata contract returned by ObjectStorage."""
    object_key: str
    content_type: str
    size_bytes: int
    sha256_hash: str
    created_at: Optional[datetime] = None


class ObjectStorage(ABC):
    @abstractmethod
    def upload(
        self,
        file_obj: BinaryIO,
        object_key: str,
        content_type: str,
        sha256_hash: Optional[str] = None
    ) -> StoredObjectMetadata:
        """
        Uploads file object to storage and returns StoredObjectMetadata.
        Guarantees that partial writes do not become valid objects.
        """
        pass

    @abstractmethod
    def get_metadata(self, object_key: str) -> Optional[StoredObjectMetadata]:
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
