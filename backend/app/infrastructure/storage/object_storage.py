import os
import uuid
from typing import Dict, Any, Optional, BinaryIO
from app.infrastructure.storage.base import ObjectStorage
from app.core.config import settings
from app.core.logging import logger


class LocalDevObjectStorage(ObjectStorage):
    def __init__(self, upload_dir: str = "storage_dev"):
        self.upload_dir = upload_dir
        os.makedirs(self.upload_dir, exist_ok=True)

    def upload(self, file_obj: BinaryIO, object_key: str, content_type: str) -> str:
        safe_key = object_key.replace("/", "_")
        file_path = os.path.join(self.upload_dir, safe_key)
        with open(file_path, "wb") as f:
            f.write(file_obj.read())
        return object_key

    def get_metadata(self, object_key: str) -> Optional[Dict[str, Any]]:
        safe_key = object_key.replace("/", "_")
        file_path = os.path.join(self.upload_dir, safe_key)
        if os.path.exists(file_path):
            return {
                "size_bytes": os.path.getsize(file_path),
                "key": object_key
            }
        return None

    def delete(self, object_key: str) -> bool:
        safe_key = object_key.replace("/", "_")
        file_path = os.path.join(self.upload_dir, safe_key)
        if os.path.exists(file_path):
            os.remove(file_path)
            return True
        return False


def get_object_storage() -> ObjectStorage:
    # Phase 1: Uses LocalDevObjectStorage adapter
    # R2ObjectStorage can be plugged in when CLOUDFLARE_R2_ENDPOINT is configured
    return LocalDevObjectStorage()
