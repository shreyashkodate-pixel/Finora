import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, field_validator


class Settings(BaseSettings):
    # Application Environment
    ENVIRONMENT: str = Field(default="local", description="local | staging | production")
    DEBUG: bool = Field(default=True)
    HOST: str = Field(default="0.0.0.0")
    PORT: int = Field(default=8000)
    ALLOWED_ORIGINS: str = Field(default="http://localhost:3000,http://localhost:8000,http://127.0.0.1:8000")

    # Database
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/helpdesk_dev"
    )

    # JWT Authentication
    JWT_SECRET: str = Field(default="dev_secret_key_change_in_production_min_32_bytes_long")
    JWT_ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=15)
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=7)

    # Google OAuth 2.0 / OIDC
    GOOGLE_OAUTH_CLIENT_ID: str = Field(default="")
    GOOGLE_OAUTH_CLIENT_SECRET: str = Field(default="")
    GOOGLE_OAUTH_REDIRECT_URI: str = Field(default="http://localhost:8000/api/v1/auth/google/callback")

    # AI Provider (Gemini)
    GEMINI_API_KEY: str = Field(default="")
    GEMINI_MODEL: str = Field(default="gemini-2.5-flash")
    GEMINI_TIMEOUT_SECONDS: int = Field(default=15)

    # Cloud Storage (Supabase Storage)
    SUPABASE_URL: str = Field(default="")
    SUPABASE_KEY: str = Field(default="")
    SUPABASE_STORAGE_BUCKET: str = Field(default="attachments")
    STORAGE_LOCAL_DIR: str = Field(default="uploads")
    MAX_FILE_SIZE_BYTES: int = Field(default=10 * 1024 * 1024)  # 10MB per SRS §7.5
    MAX_CASE_ATTACHMENTS_SIZE_BYTES: int = Field(default=50 * 1024 * 1024)  # 50MB per SRS §7.5

    # Email - Local (Gmail SMTP)
    GMAIL_SMTP_ADDRESS: str = Field(default="")
    GMAIL_SMTP_APP_PASSWORD: str = Field(default="")

    # Email - Staging / Production (Brevo HTTP API)
    BREVO_API_KEY: str = Field(default="")
    EMAIL_SENDER_ADDRESS: str = Field(default="support@yourdomain.com")
    EMAIL_SENDER_NAME: str = Field(default="AI IT Helpdesk")

    # Scheduler (The Sweep)
    ENABLE_SCHEDULER: bool = Field(default=True)
    SWEEP_INTERVAL_MINUTES: int = Field(default=5)
    ESCALATION_UNACKNOWLEDGED_HOURS: int = Field(default=2)
    ENABLE_KEEPALIVE_PING: bool = Field(default=False)
    KEEPALIVE_PING_INTERVAL_MINUTES: int = Field(default=10)

    # Client Configuration
    API_BASE_URL: str = Field(default="http://localhost:8000/api/v1")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

    def validate_startup(self) -> None:
        """
        Validate critical environment variables at startup per SRS §3.3.
        In staging/production, fail fast if required credentials are missing.
        """
        if self.ENVIRONMENT in ("staging", "production"):
            missing_vars = []
            if not self.JWT_SECRET or self.JWT_SECRET.startswith("dev_secret"):
                missing_vars.append("JWT_SECRET")
            if not self.DATABASE_URL or "localhost" in self.DATABASE_URL:
                missing_vars.append("DATABASE_URL")
            if not self.GEMINI_API_KEY:
                missing_vars.append("GEMINI_API_KEY")
            if not self.BREVO_API_KEY:
                missing_vars.append("BREVO_API_KEY")
            if not self.GOOGLE_OAUTH_CLIENT_ID:
                missing_vars.append("GOOGLE_OAUTH_CLIENT_ID")
            if not self.GOOGLE_OAUTH_CLIENT_SECRET:
                missing_vars.append("GOOGLE_OAUTH_CLIENT_SECRET")
            if not self.SUPABASE_URL:
                missing_vars.append("SUPABASE_URL")
            if not self.SUPABASE_KEY:
                missing_vars.append("SUPABASE_KEY")

            if missing_vars:
                raise RuntimeError(
                    f"Startup validation failed in {self.ENVIRONMENT} environment. "
                    f"Missing required environment variables: {', '.join(missing_vars)}"
                )


settings = Settings()
