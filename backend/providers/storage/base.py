from abc import ABC, abstractmethod
from typing import Optional


class StorageProvider(ABC):
    """Abstract interface for file and evidence storage providers per SRS §11 & §12.3."""

    @abstractmethod
    async def upload_file(
        self,
        storage_path: str,
        data: bytes,
        content_type: str,
    ) -> str:
        """
        Upload binary data to storage.
        
        Args:
            storage_path: Unique server-generated path (e.g. cases/{case_id}/{uuid}.{ext})
            data: Raw file binary bytes
            content_type: Verified MIME type
            
        Returns:
            The finalized storage path or URL.
        """
        pass

    @abstractmethod
    async def get_signed_download_url(
        self,
        storage_path: str,
        expires_in: int = 3600,
    ) -> str:
        """
        Generate a secure, time-limited download URL for an attachment.
        
        Args:
            storage_path: Storage path identifier
            expires_in: Time-to-live in seconds (default: 3600 / 1 hour)
            
        Returns:
            A presigned URL string allowing temporary direct download.
        """
        pass

    @abstractmethod
    async def delete_file(self, storage_path: str) -> bool:
        """
        Delete a file from storage.
        
        Args:
            storage_path: Storage path identifier
            
        Returns:
            True if deletion was successful or file didn't exist, False on failure.
        """
        pass

    @abstractmethod
    async def file_exists(self, storage_path: str) -> bool:
        """
        Check if a file exists in storage.
        
        Args:
            storage_path: Storage path identifier
            
        Returns:
            True if present, False otherwise.
        """
        pass

    @abstractmethod
    async def get_file_bytes(self, storage_path: str) -> bytes:
        """
        Download raw file bytes from storage (used in tests or server-side processing).
        
        Args:
            storage_path: Storage path identifier
            
        Returns:
            Raw bytes of the file.
        """
        pass
