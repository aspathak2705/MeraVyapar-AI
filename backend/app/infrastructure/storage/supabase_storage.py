import os
from typing import Dict, Any, Optional, BinaryIO
import requests

from app.infrastructure.storage.base import ObjectStorage
from app.core.config import settings
from app.core.logging import logger


class SupabaseObjectStorage(ObjectStorage):
    """
    Production Object Storage implementation for Supabase Private Storage.
    Preserves existing ObjectStorage interface.
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

    def upload(self, file_obj: BinaryIO, object_key: str, content_type: str) -> str:
        url = f"{self.supabase_url}/storage/v1/object/{self.bucket_name}/{object_key}"
        headers = self._get_headers(content_type)
        headers["x-upsert"] = "true"

        # Read file contents
        file_obj.seek(0)
        data = file_obj.read()

        response = requests.post(url, headers=headers, data=data)
        if response.status_code not in [200, 201]:
            logger.error(f"Supabase Storage upload failed ({response.status_code}): {response.text}")
            raise RuntimeError(f"Storage upload failed: {response.text}")

        return object_key

    def get_metadata(self, object_key: str) -> Optional[Dict[str, Any]]:
        # Supabase Storage metadata / info endpoint
        url = f"{self.supabase_url}/storage/v1/object/info/authenticated/{self.bucket_name}/{object_key}"
        headers = self._get_headers()

        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        return None

    def delete(self, object_key: str) -> bool:
        url = f"{self.supabase_url}/storage/v1/object/{self.bucket_name}"
        headers = self._get_headers("application/json")
        payload = {"prefixes": [object_key]}

        response = requests.delete(url, headers=headers, json=payload)
        if response.status_code == 200:
            return True
        return False
