import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Integer,
    Boolean,
    DateTime,
    ForeignKey,
    JSON,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base


class Organization(Base):
    """
    Multi-tenant enterprise organization model.
    """
    __tablename__ = "organizations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), unique=True, nullable=False, index=True)
    slug = Column(String(80), unique=True, nullable=False, index=True)
    domain_whitelist = Column(JSON, nullable=False, default=list)  # ["acme.com", "corp.acme.com"]
    sla_tier = Column(String(50), nullable=False, default="enterprise")  # enterprise, standard, basic
    max_users = Column(Integer, nullable=False, default=500)
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    policy = relationship("TenantPolicy", back_populates="organization", uselist=False, cascade="all, delete-orphan", lazy="joined")


class TenantPolicy(Base):
    """
    Organization-specific governance, retention, and security policy rules.
    """
    __tablename__ = "tenant_policies"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(
        UUID(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    data_retention_days = Column(Integer, nullable=False, default=365)
    require_mfa = Column(Boolean, nullable=False, default=False)
    allow_password_auth = Column(Boolean, nullable=False, default=True)
    allow_google_oauth = Column(Boolean, nullable=False, default=True)
    ai_auto_triage_enabled = Column(Boolean, nullable=False, default=True)
    ai_autofix_enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    organization = relationship("Organization", back_populates="policy")
