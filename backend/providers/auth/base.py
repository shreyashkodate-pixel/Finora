from abc import ABC, abstractmethod
from typing import Optional
from pydantic import BaseModel


class OAuthUserInfo(BaseModel):
    subject_id: str
    email: str
    email_verified: bool = True
    name: Optional[str] = None
    picture: Optional[str] = None


class AuthProviderInterface(ABC):
    """Abstract interface for external OAuth2/OIDC identity providers."""

    @abstractmethod
    async def exchange_code(
        self,
        code: str,
        redirect_uri: str,
        code_verifier: Optional[str] = None,
    ) -> OAuthUserInfo:
        """Exchange an authorization code for validated user profile information."""
        pass
