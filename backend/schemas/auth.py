from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field, ConfigDict

from models.enums import UserRole, AuthProvider, AvailabilityStatus


class BaseSchema(BaseModel):
    model_config = ConfigDict(extra="forbid")


class PasswordRegisterRequest(BaseSchema):
    email: EmailStr
    # Minimum 12 characters per SRS §7.4
    password: str = Field(min_length=12, max_length=128, description="Password must be at least 12 characters")
    site: Optional[str] = Field(default=None, max_length=100)


class PasswordLoginRequest(BaseSchema):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class GoogleAuthRequest(BaseSchema):
    code: str = Field(min_length=1, description="Google OAuth authorization code")
    code_verifier: Optional[str] = Field(default=None, description="PKCE code verifier for mobile/desktop clients")
    redirect_uri: str = Field(min_length=1, description="Registered redirect URI")


class RefreshTokenRequest(BaseSchema):
    refresh_token: str = Field(min_length=1)


class VerifyEmailRequest(BaseSchema):
    token: str = Field(min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    id: UUID
    email: str
    role: UserRole
    site: Optional[str] = None
    availability_status: AvailabilityStatus
    email_verified: bool
    auth_provider: AuthProvider
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AuthResponse(BaseModel):
    user: UserResponse
    tokens: TokenResponse


class MessageResponse(BaseModel):
    message: str
