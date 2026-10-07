import os
import hashlib
from typing import Dict, Any, Optional, BinaryIO
from datetime import datetime, timezone
import requests

from app.infrastructure.storage.base import (
    ObjectStorage,
    StoredObjectMetadata,
    StorageUnavailableError
)
from app.core.config import settings
from app.core.logging import logger


class SupabaseObjectStorage(ObjectStorage):
    """
    [DEPRECATED / TRANSITIONAL] Legacy Object Storage implementation for Supabase.
    Retained strictly for read/delete compatibility with historical legacy evidence.
    New evidence must use mobile app-private storage.
    """
    def __init__(self, supabase_url: Optional[str] = None, service_key_or_anon: Optional[str] = None, bucket_name: Optional[str] = None):
        self.supabase_url = (supabase_url or settings.SUPABASE_URL or "").rstrip("/")
        self.auth_token = service_key_or_anon or settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_PUBLISHABLE_KEY or ""
        self.bucket_name = bucket_name or settings.SUPABASE_STORAGE_BUCKET

    def _get_headers(self, content_type: Optional[str] = None) -> Dict[str, str]:
        headers = {
            "Authorization": f"Bearer {self.auth_token}",
            "apikey": self.auth_token,
        }
        if content_type:
            headers["Content-Type"] = content_type
        return headers

    def upload(
        self,
        file_obj: BinaryIO,
        object_key: str,
        content_type: str,
        sha256_hash: Optional[str] = None
    ) -> StoredObjectMetadata:
        url = f"{self.supabase_url}/storage/v1/object/{self.bucket_name}/{object_key}"
        headers = self._get_headers(content_type)
        headers["x-upsert"] = "true"

        # Read file contents and compute authoritative hash from actual bytes
        file_obj.seek(0)
        data = file_obj.read()
        calculated_hash = hashlib.sha256(data).hexdigest()

        if sha256_hash and sha256_hash.lower() != calculated_hash.lower():
            from app.infrastructure.storage.base import StorageValidationError
            raise StorageValidationError(
                f"Checksum mismatch: expected {sha256_hash}, calculated {calculated_hash}"
            )

        try:
            response = requests.post(url, headers=headers, data=data)
        except Exception as e:
            logger.error(f"Supabase Storage network error: {e}")
            raise StorageUnavailableError(f"Storage service unreachable: {e}")

        if response.status_code not in [200, 201]:
            logger.error(f"Supabase Storage upload failed ({response.status_code}): {response.text}")
            raise StorageUnavailableError(f"Storage upload failed: {response.text}")

        return StoredObjectMetadata(
            object_key=object_key,
            content_type=content_type,
            size_bytes=len(data),
            sha256_hash=calculated_hash,
            created_at=datetime.now(timezone.utc)
        )

    def get_metadata(self, object_key: str) -> Optional[StoredObjectMetadata]:
        url = f"{self.supabase_url}/storage/v1/object/info/authenticated/{self.bucket_name}/{object_key}"
        headers = self._get_headers()

        try:
            response = requests.get(url, headers=headers)
            if response.status_code == 200:
                data = response.json()
                size = data.get("size", 0)
                return StoredObjectMetadata(
                    object_key=object_key,
                    content_type=data.get("content_type", "application/octet-stream"),
                    size_bytes=size,
                    sha256_hash="",  # Supabase info endpoint does not standardly return sha256
                    created_at=datetime.now(timezone.utc)
                )
        except Exception as e:
            logger.warning(f"Error fetching Supabase metadata for {object_key}: {e}")
        return None

    def delete(self, object_key: str) -> bool:
        url = f"{self.supabase_url}/storage/v1/object/{self.bucket_name}"
        headers = self._get_headers("application/json")
        payload = {"prefixes": [object_key]}

        try:
            response = requests.delete(url, headers=headers, json=payload)
            if response.status_code == 200:
                return True
        except Exception as e:
            logger.warning(f"Failed deleting object {object_key} from Supabase: {e}")
        return False
