import uuid
from datetime import datetime, timezone
from typing import Optional, Tuple
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from core.config import settings
from core.security import (
    hash_password,
    verify_password,
    hash_token,
    create_access_token,
    create_refresh_token,
    decode_jwt_token,
    create_email_verification_token,
    decode_email_verification_token,
)
from models.enums import UserRole, AuthProvider
from models.user import User
from models.auth import RefreshToken
from schemas.auth import (
    PasswordRegisterRequest,
    PasswordLoginRequest,
    TokenResponse,
    UserResponse,
    AuthResponse,
)
from providers.auth.base import AuthProviderInterface, OAuthUserInfo


class AuthService:
    """Authentication and session lifecycle management service."""

    @staticmethod
    async def register_with_password(
        db: AsyncSession,
        request: PasswordRegisterRequest,
    ) -> Tuple[User, str]:
        """
        Register a new user with email and password per SRS §6 & §7.4.
        Returns (User, verification_token).
        """
        normalized_email = request.email.lower().strip()

        # Check for existing account
        stmt = select(User).where(User.email == normalized_email, User.deleted_at.is_(None))
        result = await db.execute(stmt)
        existing_user = result.scalar_one_or_none()

        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "error": {
                        "code": "EMAIL_ALREADY_EXISTS",
                        "message": "An account with this email address already exists.",
                        "details": {"email": normalized_email},
                    }
                },
            )

        hashed_pw = hash_password(request.password)
        
        # Local development skips mandatory email verification per SRS §3.3a
        is_verified = True if settings.ENVIRONMENT == "local" else False

        user = User(
            email=normalized_email,
            password_hash=hashed_pw,
            auth_provider=AuthProvider.PASSWORD,
            role=UserRole.REQUESTER,
            site=request.site,
            email_verified=is_verified,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

        verification_token = create_email_verification_token(str(user.id), user.email)
        return user, verification_token

    @staticmethod
    async def login_with_password(
        db: AsyncSession,
        request: PasswordLoginRequest,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> AuthResponse:
        """
        Authenticate with email and password.
        Returns access token and rotated refresh token per SRS §7.4.
        """
        normalized_email = request.email.lower().strip()

        stmt = select(User).where(User.email == normalized_email, User.deleted_at.is_(None))
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if not user or not user.password_hash:
            # Avoid username enumeration by running dummy verify
            verify_password("dummy_password", "$argon2id$v=19$m=8192,t=1,p=1$dummy$dummy")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error": {
                        "code": "INVALID_CREDENTIALS",
                        "message": "Invalid email address or password.",
                        "details": {},
                    }
                },
            )

        if not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error": {
                        "code": "INVALID_CREDENTIALS",
                        "message": "Invalid email address or password.",
                        "details": {},
                    }
                },
            )

        # Enforce email verification in production per SRS §3.3a & §6
        if settings.ENVIRONMENT != "local" and not user.email_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "EMAIL_NOT_VERIFIED",
                        "message": "Please verify your email address before signing in.",
                        "details": {"email": user.email},
                    }
                },
            )

        return await AuthService._issue_session_tokens(
            db=db,
            user=user,
            user_agent=user_agent,
            ip_address=ip_address,
        )

    @staticmethod
    async def login_with_google(
        db: AsyncSession,
        code: str,
        redirect_uri: str,
        provider: AuthProviderInterface,
        code_verifier: Optional[str] = None,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> AuthResponse:
        """
        Authenticate via Google OAuth 2.0 / OIDC code exchange per SRS v3.3.
        Includes Account Collision Guard per SRS §7.4.
        """
        google_info: OAuthUserInfo = await provider.exchange_code(
            code=code,
            redirect_uri=redirect_uri,
            code_verifier=code_verifier,
        )

        normalized_email = google_info.email.lower().strip()

        # Check existing user
        stmt = select(User).where(User.email == normalized_email, User.deleted_at.is_(None))
        result = await db.execute(stmt)
        existing_user = result.scalar_one_or_none()

        if existing_user:
            # Account Collision Check per SRS §7.4:
            # A Google sign-in with an email that already has a password account is treated as
            # a 409 Conflict rather than silently merged, to prevent account-takeover vectors.
            if existing_user.auth_provider == AuthProvider.PASSWORD and existing_user.oauth_subject_id != google_info.subject_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "error": {
                            "code": "ACCOUNT_COLLISION",
                            "message": "An account with this email already exists using password sign-in. Account linking is not supported in Phase 1.",
                            "details": {"email": normalized_email, "existing_provider": "password"},
                        }
                    },
                )

            user = existing_user
            if not user.oauth_subject_id:
                user.oauth_subject_id = google_info.subject_id
            # Google accounts are pre-verified per SRS §3.3a
            user.email_verified = True
        else:
            # New Google account
            user = User(
                email=normalized_email,
                auth_provider=AuthProvider.GOOGLE,
                oauth_subject_id=google_info.subject_id,
                password_hash=None,  # Nullable for OAuth accounts
                role=UserRole.REQUESTER,
                email_verified=True,  # Google already verified email per SRS §3.3a
            )
            db.add(user)
            await db.flush()

        return await AuthService._issue_session_tokens(
            db=db,
            user=user,
            user_agent=user_agent,
            ip_address=ip_address,
        )

    @staticmethod
    async def refresh_tokens(
        db: AsyncSession,
        refresh_token_str: str,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> TokenResponse:
        """
        Exchange a valid refresh token for a new access token and rotated refresh token per SRS §7.4.
        """
        try:
            payload = decode_jwt_token(refresh_token_str, expected_type="refresh")
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error": {
                        "code": "INVALID_REFRESH_TOKEN",
                        "message": "The refresh token is invalid or expired.",
                        "details": str(e),
                    }
                },
            )

        token_hash_val = hash_token(refresh_token_str)
        now = datetime.now(timezone.utc)

        # Lookup in refresh_tokens table
        stmt = select(RefreshToken).where(
            RefreshToken.token_hash == token_hash_val,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
        result = await db.execute(stmt)
        stored_token = result.scalar_one_or_none()

        if not stored_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error": {
                        "code": "TOKEN_REVOKED_OR_EXPIRED",
                        "message": "The refresh token has been revoked or expired.",
                        "details": {},
                    }
                },
            )

        # Revoke old refresh token (Token Rotation per SRS §7.4)
        stored_token.revoked_at = now

        # Fetch user
        user_stmt = select(User).where(User.id == stored_token.user_id, User.deleted_at.is_(None))
        user_res = await db.execute(user_stmt)
        user = user_res.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error": {
                        "code": "USER_NOT_FOUND",
                        "message": "The user account associated with this token no longer exists.",
                        "details": {},
                    }
                },
            )

        # Issue new token pair
        access_token, expires_in = create_access_token(
            user_id=str(user.id),
            email=user.email,
            role=user.role.value,
        )
        new_refresh_token, new_expires_at = create_refresh_token(user_id=str(user.id))

        # Store rotated refresh token
        new_stored_token = RefreshToken(
            user_id=user.id,
            token_hash=hash_token(new_refresh_token),
            expires_at=new_expires_at,
            user_agent=user_agent,
            ip_address=ip_address,
        )
        db.add(new_stored_token)
        await db.commit()

        return TokenResponse(
            access_token=access_token,
            refresh_token=new_refresh_token,
            token_type="bearer",
            expires_in=expires_in,
        )

    @staticmethod
    async def verify_email(db: AsyncSession, token_str: str) -> bool:
        """Verify user email address via signed link per SRS §6."""
        try:
            payload = decode_email_verification_token(token_str)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_VERIFICATION_TOKEN",
                        "message": "Verification link is invalid or expired.",
                        "details": str(e),
                    }
                },
            )

        user_id = payload.get("sub")
        stmt = select(User).where(User.id == uuid.UUID(user_id), User.deleted_at.is_(None))
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "USER_NOT_FOUND",
                        "message": "User not found.",
                        "details": {},
                    }
                },
            )

        user.email_verified = True
        await db.commit()
        return True

    @staticmethod
    async def logout(db: AsyncSession, refresh_token_str: str) -> None:
        """Revoke a single device session by invalidating the refresh token."""
        token_hash_val = hash_token(refresh_token_str)
        stmt = (
            update(RefreshToken)
            .where(RefreshToken.token_hash == token_hash_val, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=func.now())
        )
        await db.execute(stmt)
        await db.commit()

    @staticmethod
    async def logout_all(db: AsyncSession, user_id: uuid.UUID) -> None:
        """Revoke all active device sessions for a user per SRS §6."""
        stmt = (
            update(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=func.now())
        )
        await db.execute(stmt)
        await db.commit()

    @staticmethod
    async def _issue_session_tokens(
        db: AsyncSession,
        user: User,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> AuthResponse:
        """Helper to create and persist JWT token pair."""
        access_token, expires_in = create_access_token(
            user_id=str(user.id),
            email=user.email,
            role=user.role.value,
        )
        refresh_token, expires_at = create_refresh_token(user_id=str(user.id))

        # Store hashed refresh token
        db_token = RefreshToken(
            user_id=user.id,
            token_hash=hash_token(refresh_token),
            expires_at=expires_at,
            user_agent=user_agent,
            ip_address=ip_address,
        )
        db.add(db_token)
        await db.commit()

        user_resp = UserResponse.model_validate(user)
        token_resp = TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=expires_in,
        )
        return AuthResponse(user=user_resp, tokens=token_resp)
