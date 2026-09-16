import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import (
    Column,
    String,
    Integer,
    DateTime,
    ForeignKey,
    Enum as SQLEnum,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import CaseType, CaseStatus, CasePriority, RelationshipType


class Case(Base):
    __tablename__ = "cases"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reference_number = Column(String(32), unique=True, nullable=False, index=True)
    type = Column(
        SQLEnum(CaseType),
        default=CaseType.INCIDENT,
        nullable=False,
        index=True,
    )
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)  # Immutable original description
    status = Column(
        SQLEnum(CaseStatus),
        default=CaseStatus.NEW,
        nullable=False,
        index=True,
    )
    priority = Column(
        SQLEnum(CasePriority),
        default=CasePriority.P3,
        nullable=False,
        index=True,
    )
    requester_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    owner_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    team_id = Column(
        UUID(as_uuid=True),
        ForeignKey("teams.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    site = Column(String(100), nullable=True)
    service_id = Column(String(100), nullable=True)

    # Optimistic concurrency locking integer per SRS §7.12
    version = Column(Integer, default=1, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    closed_at = Column(DateTime(timezone=True), nullable=True)

    # Soft delete timestamp per SRS §7.10
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    # User / Team Relationships
    requester = relationship("User", foreign_keys=[requester_id])
    owner = relationship("User", foreign_keys=[owner_id])
    team = relationship("Team", foreign_keys=[team_id])

    # Related Case Entities
    messages = relationship("Message", back_populates="case", cascade="all, delete-orphan")
    attachments = relationship("Attachment", back_populates="case", cascade="all, delete-orphan")
    sla = relationship("SLA", back_populates="case", uselist=False, cascade="all, delete-orphan")
    ai_triage = relationship("AITriageResult", back_populates="case", uselist=False, cascade="all, delete-orphan")
    summary = relationship("CaseSummary", back_populates="case", uselist=False, cascade="all, delete-orphan")
    risk_assessments = relationship("CaseRiskAssessment", back_populates="case", cascade="all, delete-orphan")
    escalations = relationship("EscalationEvent", back_populates="case", cascade="all, delete-orphan")
    communication_drafts = relationship("CommunicationDraft", back_populates="case", cascade="all, delete-orphan")
    approvals = relationship("Approval", back_populates="case", cascade="all, delete-orphan")

    def __init__(self, **kwargs):
        kwargs.setdefault("type", CaseType.INCIDENT)
        kwargs.setdefault("status", CaseStatus.NEW)
        kwargs.setdefault("priority", CasePriority.P3)
        kwargs.setdefault("version", 1)
        super().__init__(**kwargs)


class CaseRelationship(Base):
    __tablename__ = "case_relationships"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    related_case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    relationship_type = Column(
        SQLEnum(RelationshipType),
        nullable=False,
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", foreign_keys=[case_id])
    related_case = relationship("Case", foreign_keys=[related_case_id])
