import logging
from typing import Optional

from core.config import settings
from providers.ai.base import AIProvider
from providers.ai.gemini import GeminiAIProvider
from providers.ai.mock import MockAIProvider

logger = logging.getLogger("helpdesk.providers.ai.factory")

_ai_provider_instance: Optional[AIProvider] = None


def get_ai_provider(force_mock: bool = False) -> AIProvider:
    """
    Factory to retrieve the appropriate AI provider instance.
    Returns GeminiAIProvider if GEMINI_API_KEY is configured and force_mock=False.
    Falls back to MockAIProvider for tests and offline/local execution.
    """
    global _ai_provider_instance

    if force_mock:
        return MockAIProvider()

    if _ai_provider_instance is not None:
        return _ai_provider_instance

    if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY != "replace_with_gemini_api_key":
        logger.info(f"Initializing GeminiAIProvider with model: {settings.GEMINI_MODEL}")
        _ai_provider_instance = GeminiAIProvider()
    else:
        logger.info("No valid GEMINI_API_KEY found; falling back to MockAIProvider.")
        _ai_provider_instance = MockAIProvider()

    return _ai_provider_instance


def set_ai_provider(provider: Optional[AIProvider]) -> None:
    """Allow overriding AI provider for tests."""
    global _ai_provider_instance
    _ai_provider_instance = provider
