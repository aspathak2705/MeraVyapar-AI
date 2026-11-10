import os
import hashlib
from typing import Dict, Any, Optional, BinaryIO
from datetime import datetime, timezone
from app.infrastructure.storage.base import (
    ObjectStorage,
    StoredObjectMetadata,
    StorageError,
    StorageUnavailableError
)
from app.core.config import settings
from app.core.logging import logger


class LocalDevObjectStorage(ObjectStorage):
    """
    Local development object storage.
    Uses atomic temp-write and replace to ensure partial writes
    never become valid objects.
    """
    def __init__(self, upload_dir: str = "storage_dev"):
        self.upload_dir = upload_dir
        os.makedirs(self.upload_dir, exist_ok=True)

    def upload(
        self,
        file_obj: BinaryIO,
        object_key: str,
        content_type: str,
        sha256_hash: Optional[str] = None
    ) -> StoredObjectMetadata:
        safe_key = object_key.replace("/", "_")
        final_path = os.path.join(self.upload_dir, safe_key)
        part_path = f"{final_path}.part"

        file_obj.seek(0)
        hasher = hashlib.sha256()
        total_size = 0

        try:
            with open(part_path, "wb") as f:
                while True:
                    chunk = file_obj.read(64 * 1024)
                    if not chunk:
                        break
                    f.write(chunk)
                    hasher.update(chunk)
                    total_size += len(chunk)

            # Atomic rename / replace
            os.replace(part_path, final_path)
        except Exception as e:
            if os.path.exists(part_path):
                try:
                    os.remove(part_path)
                except OSError:
                    pass
            raise StorageUnavailableError(f"Failed to write local object: {str(e)}")

        calculated_hash = hasher.hexdigest()
        if sha256_hash and sha256_hash.lower() != calculated_hash.lower():
            if os.path.exists(final_path):
                try:
                    os.remove(final_path)
                except OSError:
                    pass
            from app.infrastructure.storage.base import StorageValidationError
            raise StorageValidationError(
                f"Checksum mismatch: expected {sha256_hash}, calculated {calculated_hash}"
            )

        return StoredObjectMetadata(
            object_key=object_key,
            content_type=content_type,
            size_bytes=total_size,
            sha256_hash=calculated_hash,
            created_at=datetime.now(timezone.utc)
        )

    def get_metadata(self, object_key: str) -> Optional[StoredObjectMetadata]:
        safe_key = object_key.replace("/", "_")
        file_path = os.path.join(self.upload_dir, safe_key)
        if os.path.exists(file_path):
            size = os.path.getsize(file_path)
            # Compute hash on read
            with open(file_path, "rb") as f:
                file_hash = hashlib.sha256(f.read()).hexdigest()
            return StoredObjectMetadata(
                object_key=object_key,
                content_type="application/octet-stream",
                size_bytes=size,
                sha256_hash=file_hash,
                created_at=datetime.fromtimestamp(os.path.getctime(file_path), timezone.utc)
            )
        return None

    def delete(self, object_key: str) -> bool:
        safe_key = object_key.replace("/", "_")
        file_path = os.path.join(self.upload_dir, safe_key)
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
                return True
            except OSError:
                return False
        return False


def get_object_storage() -> ObjectStorage:
    if settings.SUPABASE_URL:
        from app.infrastructure.storage.supabase_storage import SupabaseObjectStorage
        return SupabaseObjectStorage()
    return LocalDevObjectStorage()
