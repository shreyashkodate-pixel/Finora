from typing import Optional, Dict, Any
import httpx
from fastapi import HTTPException, status

from core.config import settings
from providers.auth.base import AuthProviderInterface, OAuthUserInfo


class GoogleAuthProvider(AuthProviderInterface):
    """
    Google OAuth 2.0 / OIDC provider per SRS §3.1, §3.3 & §7.4.
    Exchanges authorization code server-side using client secret (never exposed to frontend).
    Supports PKCE code_verifier for Mobile/Desktop clients.
    """

    GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
    GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo"

    async def exchange_code(
        self,
        code: str,
        redirect_uri: str,
        code_verifier: Optional[str] = None,
    ) -> OAuthUserInfo:
        payload: Dict[str, Any] = {
            "client_id": settings.GOOGLE_OAUTH_CLIENT_ID,
            "client_secret": settings.GOOGLE_OAUTH_CLIENT_SECRET,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        }

        # Include PKCE code_verifier if provided by mobile/desktop client
        if code_verifier:
            payload["code_verifier"] = code_verifier

        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                token_response = await client.post(self.GOOGLE_TOKEN_URL, data=payload)
            except Exception as e:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail={
                        "error": {
                            "code": "OAUTH_PROVIDER_UNREACHABLE",
                            "message": "Failed to connect to Google OAuth service.",
                            "details": str(e),
                        }
                    },
                )

            if token_response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "error": {
                            "code": "OAUTH_EXCHANGE_FAILED",
                            "message": "Failed to exchange authorization code with Google.",
                            "details": token_response.json() if token_response.headers.get("content-type", "").startswith("application/json") else token_response.text,
                        }
                    },
                )

            token_data = token_response.json()
            access_token = token_data.get("access_token")

            # Fetch user profile using access_token
            userinfo_response = await client.get(
                self.GOOGLE_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )

            if userinfo_response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "error": {
                            "code": "OAUTH_USERINFO_FAILED",
                            "message": "Failed to retrieve user profile from Google.",
                            "details": userinfo_response.text,
                        }
                    },
                )

            userinfo = userinfo_response.json()

        subject_id = userinfo.get("sub")
        email = userinfo.get("email")

        if not subject_id or not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "OAUTH_PROFILE_INVALID",
                        "message": "Google profile missing required subject ID or email.",
                        "details": {},
                    }
                },
            )

        return OAuthUserInfo(
            subject_id=str(subject_id),
            email=email.lower().strip(),
            email_verified=bool(userinfo.get("email_verified", True)),
            name=userinfo.get("name"),
            picture=userinfo.get("picture"),
        )
