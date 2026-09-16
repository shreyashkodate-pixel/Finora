import uuid
from typing import Optional
from unittest.mock import AsyncMock, patch
import pytest
from httpx import AsyncClient

from core.security import create_email_verification_token, create_access_token
from models.enums import UserRole, AuthProvider
from models.user import User
from providers.auth.base import OAuthUserInfo
from providers.auth.google import GoogleAuthProvider


@pytest.mark.asyncio
async def test_password_registration_success(async_client: AsyncClient):
    """Verify password signup succeeds with >=12 char password per SRS §7.4."""
    payload = {
        "email": "employee@example.com",
        "password": "SecurePassword2026!#",
        "site": "Campus North",
    }
    response = await async_client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "employee@example.com"
    assert data["role"] == "requester"
    assert data["auth_provider"] == "password"
    assert data["site"] == "Campus North"


@pytest.mark.asyncio
async def test_password_registration_short_password_rejected(async_client: AsyncClient):
    """Verify password signup rejects passwords shorter than 12 characters per SRS §7.4."""
    payload = {
        "email": "short_pw@example.com",
        "password": "short",  # Less than 12 chars
    }
    response = await async_client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422
    data = response.json()
    assert data["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.asyncio
async def test_duplicate_registration_returns_409(async_client: AsyncClient):
    """Verify duplicate email registration returns 409 Conflict."""
    payload = {
        "email": "duplicate@example.com",
        "password": "ValidPassword1234!",
    }
    res1 = await async_client.post("/api/v1/auth/register", json=payload)
    assert res1.status_code == 201

    res2 = await async_client.post("/api/v1/auth/register", json=payload)
    assert res2.status_code == 409
    data = res2.json()
    assert data["error"]["code"] == "EMAIL_ALREADY_EXISTS"


@pytest.mark.asyncio
async def test_password_login_success(async_client: AsyncClient):
    """Verify login with correct password returns access and refresh tokens per SRS §7.4."""
    # Register
    reg_payload = {
        "email": "login_user@example.com",
        "password": "ValidPassword1234!",
    }
    await async_client.post("/api/v1/auth/register", json=reg_payload)

    # Login
    login_payload = {
        "email": "login_user@example.com",
        "password": "ValidPassword1234!",
    }
    response = await async_client.post("/api/v1/auth/login", json=login_payload)
    assert response.status_code == 200
    data = response.json()
    assert "tokens" in data
    assert "access_token" in data["tokens"]
    assert "refresh_token" in data["tokens"]
    assert data["tokens"]["token_type"] == "bearer"
    assert data["user"]["email"] == "login_user@example.com"


@pytest.mark.asyncio
async def test_password_login_wrong_password(async_client: AsyncClient):
    """Verify login with wrong password returns 401 Unauthorized."""
    reg_payload = {
        "email": "wrong_pw@example.com",
        "password": "ValidPassword1234!",
    }
    await async_client.post("/api/v1/auth/register", json=reg_payload)

    login_payload = {
        "email": "wrong_pw@example.com",
        "password": "WrongPassword9999!",
    }
    response = await async_client.post("/api/v1/auth/login", json=login_payload)
    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "INVALID_CREDENTIALS"


@pytest.mark.asyncio
async def test_refresh_token_rotation(async_client: AsyncClient):
    """Verify token refresh rotates the refresh token and revokes the old one per SRS §7.4."""
    reg_payload = {
        "email": "rotate_user@example.com",
        "password": "ValidPassword1234!",
    }
    await async_client.post("/api/v1/auth/register", json=reg_payload)
    login_res = await async_client.post("/api/v1/auth/login", json=reg_payload)
    tokens = login_res.json()["tokens"]
    old_refresh_token = tokens["refresh_token"]

    # First refresh succeeds
    refresh_res = await async_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh_token},
    )
    assert refresh_res.status_code == 200
    new_tokens = refresh_res.json()
    assert new_tokens["refresh_token"] != old_refresh_token

    # Reusing the old refresh token must be rejected (revoked on use)
    reuse_res = await async_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh_token},
    )
    assert reuse_res.status_code == 401
    assert reuse_res.json()["error"]["code"] == "TOKEN_REVOKED_OR_EXPIRED"


@pytest.mark.asyncio
async def test_google_oauth_signup_and_account_collision(async_client: AsyncClient):
    """Verify Google OAuth signup and Account Collision 409 Conflict per SRS §7.4."""
    # 1. New user signs up via Google OAuth
    mock_oauth_info = OAuthUserInfo(
        subject_id="google-sub-99999",
        email="google_user@example.com",
        email_verified=True,
    )

    with patch.object(GoogleAuthProvider, "exchange_code", new_callable=AsyncMock) as mock_exchange:
        mock_exchange.return_value = mock_oauth_info

        google_res = await async_client.post(
            "/api/v1/auth/google",
            json={"code": "mock_auth_code", "redirect_uri": "http://localhost:3000/callback"},
        )
        assert google_res.status_code == 200
        data = google_res.json()
        assert data["user"]["email"] == "google_user@example.com"
        assert data["user"]["auth_provider"] == "google"
        assert data["user"]["email_verified"] is True
        assert "access_token" in data["tokens"]

    # 2. Pre-existing password user attempts to sign in via Google OAuth -> 409 Conflict
    # First create a password user
    pwd_payload = {
        "email": "collision_target@example.com",
        "password": "SecurePassword1234!",
    }
    await async_client.post("/api/v1/auth/register", json=pwd_payload)

    # Now attempt Google sign-in with the exact same email
    collision_oauth_info = OAuthUserInfo(
        subject_id="google-sub-attacker-123",
        email="collision_target@example.com",
        email_verified=True,
    )

    with patch.object(GoogleAuthProvider, "exchange_code", new_callable=AsyncMock) as mock_exchange:
        mock_exchange.return_value = collision_oauth_info

        collision_res = await async_client.post(
            "/api/v1/auth/google",
            json={"code": "mock_auth_code_2", "redirect_uri": "http://localhost:3000/callback"},
        )
        assert collision_res.status_code == 409
        collision_data = collision_res.json()
        assert collision_data["error"]["code"] == "ACCOUNT_COLLISION"


@pytest.mark.asyncio
async def test_verify_email_flow(async_client: AsyncClient, test_db):
    """Verify email verification endpoint updates email_verified flag per SRS §6."""
    user = User(
        email="verify_me@example.com",
        password_hash="dummy_hash",
        email_verified=False,
    )
    test_db.add(user)
    await test_db.commit()

    # Generate token
    token = create_email_verification_token(str(user.id), user.email)

    response = await async_client.post("/api/v1/auth/verify-email", json={"token": token})
    assert response.status_code == 200
    assert response.json()["message"] == "Email address verified successfully."


@pytest.mark.asyncio
async def test_get_current_user_profile(async_client: AsyncClient):
    """Verify /api/v1/auth/me returns profile when authenticated and 401 when missing."""
    # 1. Unauthenticated request
    unauth_res = await async_client.get("/api/v1/auth/me")
    assert unauth_res.status_code == 401

    # 2. Authenticated request
    reg_payload = {
        "email": "profile_user@example.com",
        "password": "ValidPassword1234!",
    }
    await async_client.post("/api/v1/auth/register", json=reg_payload)
    login_res = await async_client.post("/api/v1/auth/login", json=reg_payload)
    access_token = login_res.json()["tokens"]["access_token"]

    auth_res = await async_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert auth_res.status_code == 200
    assert auth_res.json()["email"] == "profile_user@example.com"


@pytest.mark.asyncio
async def test_require_roles_enforcement():
    """Verify require_roles allows matching roles and raises 403 PERMISSION_DENIED otherwise."""
    from api.deps import require_roles
    from fastapi import HTTPException

    checker = require_roles([UserRole.OPERATOR, UserRole.ADMINISTRATOR])

    # Operator is allowed
    operator = User(role=UserRole.OPERATOR, email_verified=True)
    result = await checker(current_user=operator)
    assert result == operator

    # Requester is denied
    requester = User(role=UserRole.REQUESTER, email_verified=True)
    with pytest.raises(HTTPException) as exc_info:
        await checker(current_user=requester)
    assert exc_info.value.status_code == 403
    assert exc_info.value.detail["error"]["code"] == "PERMISSION_DENIED"


@pytest.mark.asyncio
async def test_unverified_email_blocked_in_production():
    """Verify unverified email is blocked in non-local environments per SRS §6."""
    from api.deps import get_current_active_user
    from fastapi import HTTPException

    with patch("api.deps.settings.ENVIRONMENT", "production"):
        unverified_user = User(role=UserRole.REQUESTER, email_verified=False)
        with pytest.raises(HTTPException) as exc_info:
            await get_current_active_user(current_user=unverified_user)
        assert exc_info.value.status_code == 403
        assert exc_info.value.detail["error"]["code"] == "EMAIL_NOT_VERIFIED"

