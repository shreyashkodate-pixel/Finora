from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_user, get_current_active_user
from core.rate_limit import auth_rate_limiter
from db.session import get_db_session
from models.user import User
from providers.auth.google import GoogleAuthProvider
from schemas.auth import (
    PasswordRegisterRequest,
    PasswordLoginRequest,
    GoogleAuthRequest,
    RefreshTokenRequest,
    VerifyEmailRequest,
    TokenResponse,
    UserResponse,
    AuthResponse,
    MessageResponse,
)
from services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(auth_rate_limiter)],
)
async def register(
    request_data: PasswordRegisterRequest,
    db: AsyncSession = Depends(get_db_session),
) -> UserResponse:
    """Register a new user account with email and password per SRS §6 & §7.4."""
    user, verification_token = await AuthService.register_with_password(
        db=db,
        request=request_data,
    )
    # Email notification dispatch will be integrated in feature/notifications-email
    return UserResponse.model_validate(user)


@router.post(
    "/login",
    response_model=AuthResponse,
    dependencies=[Depends(auth_rate_limiter)],
)
async def login(
    request: Request,
    request_data: PasswordLoginRequest,
    db: AsyncSession = Depends(get_db_session),
) -> AuthResponse:
    """Authenticate with email and password, returning access and refresh tokens per SRS §7.4."""
    user_agent = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    return await AuthService.login_with_password(
        db=db,
        request=request_data,
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.post(
    "/google",
    response_model=AuthResponse,
    dependencies=[Depends(auth_rate_limiter)],
)
async def google_login(
    request: Request,
    request_data: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db_session),
) -> AuthResponse:
    """
    Exchange Google OAuth 2.0 authorization code (with PKCE support) per SRS v3.3.
    Includes account collision guard per SRS §7.4.
    """
    user_agent = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    return await AuthService.login_with_google(
        db=db,
        code=request_data.code,
        redirect_uri=request_data.redirect_uri,
        code_verifier=request_data.code_verifier,
        provider=GoogleAuthProvider(),
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_tokens(
    request: Request,
    request_data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db_session),
) -> TokenResponse:
    """Rotate and refresh access token using valid refresh token per SRS §7.4."""
    user_agent = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    return await AuthService.refresh_tokens(
        db=db,
        refresh_token_str=request_data.refresh_token,
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(
    request_data: VerifyEmailRequest,
    db: AsyncSession = Depends(get_db_session),
) -> MessageResponse:
    """Verify email address using signed verification link token per SRS §6."""
    await AuthService.verify_email(db=db, token_str=request_data.token)
    return MessageResponse(message="Email address verified successfully.")


@router.post("/logout", response_model=MessageResponse)
async def logout(
    request_data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db_session),
) -> MessageResponse:
    """Revoke a single device session."""
    await AuthService.logout(db=db, refresh_token_str=request_data.refresh_token)
    return MessageResponse(message="Logged out successfully.")


@router.post("/logout-all", response_model=MessageResponse)
async def logout_all(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> MessageResponse:
    """Revoke all active device sessions for current user per SRS §6."""
    await AuthService.logout_all(db=db, user_id=current_user.id)
    return MessageResponse(message="All device sessions revoked successfully.")


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Retrieve authenticated user profile."""
    return UserResponse.model_validate(current_user)
