import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import (
    Column,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Enum as SQLEnum,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import UserRole, AuthProvider, AvailabilityStatus


class Team(Base):
    __tablename__ = "teams"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=True)
    lead_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    members = relationship("User", foreign_keys="User.team_id", back_populates="team")
    lead = relationship("User", foreign_keys=[lead_id], post_update=True)


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    
    # Nullable for Google OAuth accounts per SRS v3.3
    password_hash = Column(String(255), nullable=True)
    
    auth_provider = Column(
        SQLEnum(AuthProvider),
        default=AuthProvider.PASSWORD,
        nullable=False,
    )
    oauth_subject_id = Column(String(255), nullable=True, index=True)
    
    role = Column(
        SQLEnum(UserRole),
        default=UserRole.REQUESTER,
        nullable=False,
        index=True,
    )
    team_id = Column(
        UUID(as_uuid=True),
        ForeignKey("teams.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    site = Column(String(100), nullable=True)
    availability_status = Column(
        SQLEnum(AvailabilityStatus),
        default=AvailabilityStatus.AVAILABLE,
        nullable=False,
    )
    email_verified = Column(Boolean, default=False, nullable=False)
    
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    # Soft delete timestamp per SRS §7.10
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    team = relationship("Team", foreign_keys=[team_id], back_populates="members")

    def __init__(self, **kwargs):
        kwargs.setdefault("role", UserRole.REQUESTER)
        kwargs.setdefault("auth_provider", AuthProvider.PASSWORD)
        kwargs.setdefault("availability_status", AvailabilityStatus.AVAILABLE)
        kwargs.setdefault("email_verified", False)
        super().__init__(**kwargs)
