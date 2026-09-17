import logging
from typing import Optional
import httpx
from fastapi import HTTPException, status

from core.config import settings
from providers.storage.base import StorageProvider

logger = logging.getLogger(__name__)


class SupabaseStorageProvider(StorageProvider):
    """
    Supabase Storage Provider implementing direct REST API access per SRS §7.5 & §12.3.
    Uses async httpx client to communicate with Supabase Storage REST API,
    avoiding heavy or platform-dependent native client dependencies.
    """

    def __init__(
        self,
        supabase_url: Optional[str] = None,
        supabase_key: Optional[str] = None,
        bucket_name: Optional[str] = None,
    ):
        self.supabase_url = (supabase_url or settings.SUPABASE_URL).rstrip("/")
        self.supabase_key = supabase_key or settings.SUPABASE_KEY
        self.bucket = bucket_name or settings.SUPABASE_STORAGE_BUCKET or "attachments"
        self.storage_base_url = f"{self.supabase_url}/storage/v1"

    @property
    def _headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.supabase_key}",
            "apiKey": self.supabase_key,
        }

    async def upload_file(
        self,
        storage_path: str,
        data: bytes,
        content_type: str,
    ) -> str:
        clean_path = storage_path.lstrip("/")
        url = f"{self.storage_base_url}/object/{self.bucket}/{clean_path}"
        headers = self._headers.copy()
        headers["Content-Type"] = content_type

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, headers=headers, content=data)
            
            # If object already exists (e.g. idempotency retry), update it
            if response.status_code == 409 or (response.status_code == 400 and "already exists" in response.text.lower()):
                put_response = await client.put(url, headers=headers, content=data)
                if put_response.status_code not in (200, 201):
                    logger.error("Failed to update existing Supabase storage object: %s", put_response.text)
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail={
                            "error": {
                                "code": "STORAGE_UPLOAD_FAILED",
                                "message": "Failed to upload file to cloud storage.",
                                "details": {"supabase_error": put_response.text},
                            }
                        },
                    )
                return clean_path

            if response.status_code not in (200, 201):
                logger.error("Failed to upload to Supabase Storage (%s): %s", response.status_code, response.text)
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={
                        "error": {
                            "code": "STORAGE_UPLOAD_FAILED",
                            "message": "Failed to upload file to cloud storage.",
                            "details": {"supabase_error": response.text},
                        }
                    },
                )

            return clean_path

    async def get_signed_download_url(
        self,
        storage_path: str,
        expires_in: int = 3600,
    ) -> str:
        clean_path = storage_path.lstrip("/")
        url = f"{self.storage_base_url}/object/sign/{self.bucket}/{clean_path}"
        headers = self._headers.copy()
        headers["Content-Type"] = "application/json"
        payload = {"expiresIn": expires_in}

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code != 200:
                logger.error("Failed to generate Supabase signed URL (%s): %s", response.status_code, response.text)
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={
                        "error": {
                            "code": "STORAGE_SIGN_FAILED",
                            "message": "Failed to generate download URL from storage provider.",
                            "details": {"supabase_error": response.text},
                        }
                    },
                )

            data = response.json()
            signed_url_path = data.get("signedURL")
            if not signed_url_path:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={
                        "error": {
                            "code": "STORAGE_SIGN_FAILED",
                            "message": "Storage provider returned empty signed URL path.",
                            "details": {},
                        }
                    },
                )

            if signed_url_path.startswith("http"):
                return signed_url_path
            
            # Format full signed URL with base URL
            if signed_url_path.startswith("/storage/v1"):
                return f"{self.supabase_url}{signed_url_path}"
            return f"{self.storage_base_url}{signed_url_path}"

    async def delete_file(self, storage_path: str) -> bool:
        clean_path = storage_path.lstrip("/")
        # Supabase Storage REST supports deleting objects with prefixes payload or directly
        url = f"{self.storage_base_url}/object/{self.bucket}/{clean_path}"
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.delete(url, headers=self._headers)
            if response.status_code in (200, 204, 404):
                return True
            logger.warning("Supabase delete returned status %s: %s", response.status_code, response.text)
            return False

    async def file_exists(self, storage_path: str) -> bool:
        clean_path = storage_path.lstrip("/")
        url = f"{self.storage_base_url}/object/info/{self.bucket}/{clean_path}"
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(url, headers=self._headers)
            return response.status_code == 200

    async def get_file_bytes(self, storage_path: str) -> bytes:
        clean_path = storage_path.lstrip("/")
        url = f"{self.storage_base_url}/object/authenticated/{self.bucket}/{clean_path}"
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url, headers=self._headers)
            if response.status_code == 404:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail={
                        "error": {
                            "code": "FILE_NOT_FOUND",
                            "message": f"File '{storage_path}' not found in Supabase storage.",
                            "details": {},
                        }
                    },
                )
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={
                        "error": {
                            "code": "STORAGE_DOWNLOAD_FAILED",
                            "message": "Failed to download file from Supabase storage.",
                            "details": {"supabase_error": response.text},
                        }
                    },
                )
            return response.content
