import os
import time
import hmac
import hashlib
from typing import Optional
from fastapi import HTTPException, status

from core.config import settings
from providers.storage.base import StorageProvider


class LocalStorageProvider(StorageProvider):
    """
    Local filesystem storage provider for offline development and testing per SRS §12.1.
    Persists uploads in a local directory and generates signed local URLs.
    """

    def __init__(self, base_dir: Optional[str] = None, base_url: Optional[str] = None):
        self.base_dir = base_dir or getattr(settings, "STORAGE_LOCAL_DIR", "uploads")
        self.base_url = base_url or getattr(settings, "API_BASE_URL", "http://localhost:8000/api/v1")
        self.signing_secret = settings.JWT_SECRET.encode("utf-8")
        os.makedirs(self.base_dir, exist_ok=True)

    def _resolve_full_path(self, storage_path: str) -> str:
        # Prevent directory traversal
        clean_path = storage_path.lstrip("/").replace("..", "")
        return os.path.join(self.base_dir, clean_path)

    async def upload_file(
        self,
        storage_path: str,
        data: bytes,
        content_type: str,
    ) -> str:
        full_path = self._resolve_full_path(storage_path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, "wb") as f:
            f.write(data)
        return storage_path

    async def get_signed_download_url(
        self,
        storage_path: str,
        expires_in: int = 3600,
    ) -> str:
        expires_at = int(time.time()) + expires_in
        # Create HMAC-SHA256 signature for URL validation
        sig_data = f"{storage_path}:{expires_at}".encode("utf-8")
        signature = hmac.new(self.signing_secret, sig_data, hashlib.sha256).hexdigest()
        
        return f"{self.base_url}/attachments/raw/{storage_path}?expires={expires_at}&signature={signature}"

    def verify_signed_url_signature(self, storage_path: str, expires_at: int, signature: str) -> bool:
        """Verify URL signature hasn't expired or been tampered with."""
        if time.time() > expires_at:
            return False
        sig_data = f"{storage_path}:{expires_at}".encode("utf-8")
        expected_sig = hmac.new(self.signing_secret, sig_data, hashlib.sha256).hexdigest()
        return hmac.compare_digest(signature, expected_sig)

    async def delete_file(self, storage_path: str) -> bool:
        full_path = self._resolve_full_path(storage_path)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
                return True
            except OSError:
                return False
        return True

    async def file_exists(self, storage_path: str) -> bool:
        full_path = self._resolve_full_path(storage_path)
        return os.path.isfile(full_path)

    async def get_file_bytes(self, storage_path: str) -> bytes:
        full_path = self._resolve_full_path(storage_path)
        if not os.path.isfile(full_path):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "FILE_NOT_FOUND",
                        "message": f"File '{storage_path}' not found in storage.",
                        "details": {},
                    }
                },
            )
        with open(full_path, "rb") as f:
            return f.read()
