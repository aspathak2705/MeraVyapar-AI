import hashlib
from typing import BinaryIO, Tuple
from app.infrastructure.storage.base import StorageValidationError


# Supported MIME types mapped to expected magic-byte headers
# JPEG: \xFF\xD8\xFF
# PNG:  \x89PNG\r\n\x1a\n (\x89\x50\x4e\x47\x0d\x0a\x1a\x0a)
# PDF:  %PDF- (\x25\x50\x44\x46\x2d)
SUPPORTED_FILE_SIGNATURES = {
    "image/jpeg": [b"\xff\xd8\xff"],
    "image/png": [b"\x89PNG\r\n\x1a\n"],
    "application/pdf": [b"%PDF-"],
}

SUPPORTED_MIME_TYPES = set(SUPPORTED_FILE_SIGNATURES.keys())
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


def validate_file_signature_and_hash(
    file_obj: BinaryIO,
    declared_content_type: str,
    max_size: int = MAX_FILE_SIZE_BYTES
) -> Tuple[str, int]:
    """
    Validates:
    1. Declared MIME type is in supported set (JPEG, PNG, PDF).
    2. Header magic bytes match declared format.
    3. File is non-empty and does not exceed max_size.
    4. Computes SHA-256 in a streaming/chunked manner.

    Returns:
        (sha256_hex_hash, total_bytes)
    Raises:
        StorageValidationError on any validation failure.
    """
    if declared_content_type not in SUPPORTED_MIME_TYPES:
        raise StorageValidationError(
            f"Unsupported file MIME type: {declared_content_type}. "
            f"Allowed types: {sorted(list(SUPPORTED_MIME_TYPES))}"
        )

    # Rewind stream to beginning
    file_obj.seek(0)
    header = file_obj.read(16)
    if not header:
        raise StorageValidationError("Empty file payload rejected.")

    # Validate magic bytes against declared type
    expected_prefixes = SUPPORTED_FILE_SIGNATURES[declared_content_type]
    matches = any(header.startswith(pfx) for pfx in expected_prefixes)
    if not matches:
        raise StorageValidationError(
            f"File content does not match declared type '{declared_content_type}'."
        )

    # Rewind and stream chunked SHA-256 and size computation
    file_obj.seek(0)
    hasher = hashlib.sha256()
    total_size = 0
    chunk_size = 64 * 1024  # 64 KB chunks

    while True:
        chunk = file_obj.read(chunk_size)
        if not chunk:
            break
        total_size += len(chunk)
        if total_size > max_size:
            raise StorageValidationError(
                f"File size exceeds maximum allowed limit of {max_size // (1024 * 1024)}MB."
            )
        hasher.update(chunk)

    if total_size == 0:
        raise StorageValidationError("Empty file payload rejected.")

    # Rewind stream so subsequent callers can read
    file_obj.seek(0)
    return hasher.hexdigest(), total_size
