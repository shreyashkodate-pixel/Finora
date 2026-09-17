from core.config import settings
from providers.storage.base import StorageProvider
from providers.storage.local import LocalStorageProvider
from providers.storage.supabase import SupabaseStorageProvider


_storage_provider_instance: StorageProvider | None = None


def get_storage_provider() -> StorageProvider:
    """
    Factory function providing the appropriate storage provider based on environment
    and configured credentials per SRS §3.3 & §12.1.
    """
    global _storage_provider_instance
    if _storage_provider_instance is not None:
        return _storage_provider_instance

    # If Supabase credentials are provided and valid, use SupabaseStorageProvider
    if settings.SUPABASE_URL and settings.SUPABASE_KEY and not settings.SUPABASE_URL.startswith("replace_with"):
        _storage_provider_instance = SupabaseStorageProvider(
            supabase_url=settings.SUPABASE_URL,
            supabase_key=settings.SUPABASE_KEY,
            bucket_name=settings.SUPABASE_STORAGE_BUCKET,
        )
    else:
        # Fall back to LocalStorageProvider in local dev/testing
        _storage_provider_instance = LocalStorageProvider()

    return _storage_provider_instance


def set_storage_provider(provider: StorageProvider | None) -> None:
    """Override or reset storage provider instance (primarily for test fixtures)."""
    global _storage_provider_instance
    _storage_provider_instance = provider


__all__ = [
    "StorageProvider",
    "LocalStorageProvider",
    "SupabaseStorageProvider",
    "get_storage_provider",
    "set_storage_provider",
]
