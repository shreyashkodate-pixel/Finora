import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Tuple, Optional

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, InvalidHashError

from core.config import settings

# Configure Argon2id per SRS §3.3a
if settings.ENVIRONMENT == "local":
    # Fast hashing for local development cycle logins
    _hasher = PasswordHasher(time_cost=1, memory_cost=8192, parallelism=1)
else:
    # Full production parameters (memory >= 19 MiB, iterations 2) per SRS §7.4
    _hasher = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)


def hash_password(password: str) -> str:
    """Hash a plaintext password using Argon2id."""
    return _hasher.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against an Argon2id hash."""
    if not hashed_password:
        return False
    try:
        return _hasher.verify(hashed_password, password)
    except Exception:
        return False


def hash_token(token: str) -> str:
    """Hash a refresh token using SHA-256 for secure database storage."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_access_token(user_id: str, email: str, role: str) -> Tuple[str, int]:
    """
    Generate an access JWT per SRS §7.4.
    Returns (token_string, expires_in_seconds).
    """
    if settings.ENVIRONMENT == "local":
        expires_delta = timedelta(hours=24)  # Avoid re-login friction in local dev (§3.3a)
    else:
        expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)  # 15 minutes

    now = datetime.now(timezone.utc)
    expires_at = now + expires_delta
    expires_in = int(expires_delta.total_seconds())

    payload: Dict[str, Any] = {
        "sub": str(user_id),
        "email": email,
        "role": role,
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }

    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    return token, expires_in


def create_refresh_token(user_id: str) -> Tuple[str, datetime]:
    """
    Generate a refresh JWT per SRS §7.4.
    Returns (token_string, expires_at_datetime).
    """
    expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    now = datetime.now(timezone.utc)
    expires_at = now + expires_delta

    payload: Dict[str, Any] = {
        "sub": str(user_id),
        "jti": secrets.token_hex(16),  # Unique token ID for rotation
        "type": "refresh",
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }

    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    return token, expires_at


def decode_jwt_token(token: str, expected_type: str = "access") -> Dict[str, Any]:
    """
    Decode and validate a JWT.
    Raises jwt.PyJWTError on invalid signature, expiration, or type mismatch.
    """
    payload = jwt.decode(
        token,
        settings.JWT_SECRET,
        algorithms=[settings.JWT_ALGORITHM],
        options={"require": ["sub", "exp", "iat"]},
    )
    if payload.get("type") != expected_type:
        raise jwt.InvalidTokenError(
            f"Token type mismatch: expected {expected_type}, got {payload.get('type')}"
        )
    return payload


def create_email_verification_token(user_id: str, email: str) -> str:
    """Generate a signed time-limited token for email verification (24h valid)."""
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=24)
    payload = {
        "sub": str(user_id),
        "email": email,
        "type": "email_verification",
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_email_verification_token(token: str) -> Dict[str, Any]:
    """Decode and validate an email verification token."""
    return decode_jwt_token(token, expected_type="email_verification")
