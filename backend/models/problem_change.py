import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    DateTime,
    ForeignKey,
    Enum as SQLEnum,
    Text,
    func,
    Boolean,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import (
    ProblemStatus,
    CasePriority,
    ChangeType,
    ChangeStatus,
    RiskLevel,
    MajorIncidentStatus,
)


class Problem(Base):
    """
    ITIL Problem entity for root-cause analysis and incident recurrence elimination.
    """
    __tablename__ = "problems"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    problem_number = Column(String(32), unique=True, nullable=False, index=True)
    title = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=False)
    root_cause = Column(Text, nullable=True)
    workaround = Column(Text, nullable=True)
    status = Column(
        SQLEnum(ProblemStatus),
        default=ProblemStatus.OPEN,
        nullable=False,
        index=True,
    )
    priority = Column(
        SQLEnum(CasePriority),
        default=CasePriority.P3,
        nullable=False,
    )
    owner_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    owner = relationship("User", foreign_keys=[owner_id])
    case_links = relationship("ProblemCaseLink", back_populates="problem", cascade="all, delete-orphan")
    known_errors = relationship("KnownError", back_populates="problem", cascade="all, delete-orphan")
    change_requests = relationship("ChangeRequest", back_populates="problem")


class ProblemCaseLink(Base):
    """
    Many-to-Many junction between Problems and Incidents/Cases.
    """
    __tablename__ = "problem_case_links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    problem_id = Column(
        UUID(as_uuid=True),
        ForeignKey("problems.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    linked_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    linked_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    problem = relationship("Problem", back_populates="case_links")
    case = relationship("Case")
    linker = relationship("User", foreign_keys=[linked_by])


class KnownError(Base):
    """
    Known Error Database (KEDB) article linked to an ongoing or resolved Problem.
    """
    __tablename__ = "known_errors"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    problem_id = Column(
        UUID(as_uuid=True),
        ForeignKey("problems.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title = Column(String(255), nullable=False)
    symptoms = Column(Text, nullable=False)
    workaround = Column(Text, nullable=False)
    permanent_fix = Column(Text, nullable=True)
    published = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    problem = relationship("Problem", back_populates="known_errors")


class ChangeRequest(Base):
    """
    ITIL Change Management entity for standard, normal, and emergency changes with CAB approval.
    """
    __tablename__ = "change_requests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    change_number = Column(String(32), unique=True, nullable=False, index=True)
    title = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=False)
    reason = Column(Text, nullable=False)
    risk_level = Column(
        SQLEnum(RiskLevel),
        default=RiskLevel.LOW,
        nullable=False,
    )
    change_type = Column(
        SQLEnum(ChangeType),
        default=ChangeType.NORMAL,
        nullable=False,
    )
    status = Column(
        SQLEnum(ChangeStatus),
        default=ChangeStatus.DRAFT,
        nullable=False,
        index=True,
    )
    requester_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    cab_approver_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    problem_id = Column(
        UUID(as_uuid=True),
        ForeignKey("problems.id", ondelete="SET NULL"),
        nullable=True,
    )
    implementation_plan = Column(Text, nullable=False)
    test_plan = Column(Text, nullable=False)
    rollback_plan = Column(Text, nullable=False)
    scheduled_start = Column(DateTime(timezone=True), nullable=True)
    scheduled_end = Column(DateTime(timezone=True), nullable=True)
    cab_feedback = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    requester = relationship("User", foreign_keys=[requester_id])
    cab_approver = relationship("User", foreign_keys=[cab_approver_id])
    problem = relationship("Problem", back_populates="change_requests")


class MajorIncident(Base):
    """
    Major Incident Management workspace for P1 critical outages.
    """
    __tablename__ = "major_incidents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    incident_number = Column(String(32), unique=True, nullable=False, index=True)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    title = Column(String(255), nullable=False)
    status = Column(
        SQLEnum(MajorIncidentStatus),
        default=MajorIncidentStatus.DECLARED,
        nullable=False,
        index=True,
    )
    commander_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    bridge_url = Column(String(512), nullable=True)
    communications_lead_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    executive_summary = Column(Text, nullable=True)
    impact_summary = Column(Text, nullable=True)
    declared_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    mitigated_at = Column(DateTime(timezone=True), nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    post_mortem_url = Column(String(512), nullable=True)

    # Relationships
    case = relationship("Case")
    commander = relationship("User", foreign_keys=[commander_id])
    communications_lead = relationship("User", foreign_keys=[communications_lead_id])
    timeline_events = relationship("MajorIncidentTimeline", back_populates="major_incident", cascade="all, delete-orphan")


class MajorIncidentTimeline(Base):
    """
    Chronological event log for a Major Incident war-room / post-mortem.
    """
    __tablename__ = "major_incident_timelines"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    major_incident_id = Column(
        UUID(as_uuid=True),
        ForeignKey("major_incidents.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    author_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    summary = Column(String(255), nullable=False)
    details = Column(Text, nullable=True)
    event_timestamp = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    major_incident = relationship("MajorIncident", back_populates="timeline_events")
    author = relationship("User", foreign_keys=[author_id])
