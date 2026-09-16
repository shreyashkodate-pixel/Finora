import uuid
from datetime import datetime
from typing import Optional, Any
from sqlalchemy import (
    Column,
    String,
    Float,
    DateTime,
    ForeignKey,
    Enum as SQLEnum,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.types import JSON
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import (
    CasePriority,
    ConfidenceLevel,
    RiskLevel,
    EscalationTrigger,
    EscalationStatus,
    DraftType,
    DraftStatus,
)

# Use JSONB on PostgreSQL, standard JSON elsewhere for cross-dialect compatibility
JSONType = JSON().with_variant(JSONB, "postgresql")


class AITriageResult(Base):
    """
    AI Case Analysis result per SRS §5.2.
    Surfaced as recommendations only; never auto-applied.
    """
    __tablename__ = "ai_triage_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    suggested_category = Column(String(100), nullable=True)
    suggested_severity = Column(String(50), nullable=True)
    suggested_priority = Column(SQLEnum(CasePriority), nullable=True)
    
    # Confidence level displayed to user (enum only, no bare score per SRS §4)
    confidence_level = Column(
        SQLEnum(ConfidenceLevel),
        default=ConfidenceLevel.MODERATE,
        nullable=False,
    )
    confidence_score = Column(Float, nullable=True)  # Internal only
    
    supporting_factors = Column(JSONType, nullable=True)
    missing_info = Column(JSONType, nullable=True)
    suggested_team_id = Column(
        UUID(as_uuid=True),
        ForeignKey("teams.id", ondelete="SET NULL"),
        nullable=True,
    )
    recommended_next_action = Column(Text, nullable=True)
    related_case_ids = Column(JSONType, nullable=True)
    
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", back_populates="ai_triage")
    suggested_team = relationship("Team", foreign_keys=[suggested_team_id])


class CaseSummary(Base):
    """
    Continuously maintained AI case summary per SRS §5.3.
    """
    __tablename__ = "case_summaries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    summary_text = Column(Text, nullable=False)
    last_source_message_id = Column(
        UUID(as_uuid=True),
        ForeignKey("messages.id", ondelete="SET NULL"),
        nullable=True,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", back_populates="summary")
    last_source_message = relationship("Message", foreign_keys=[last_source_message_id])


class CaseRiskAssessment(Base):
    """
    Periodic risk score computed by the Sweep per SRS §5.7.
    """
    __tablename__ = "case_risk_assessments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    risk_level = Column(
        SQLEnum(RiskLevel),
        default=RiskLevel.LOW,
        nullable=False,
        index=True,
    )
    # Structured signals: inactivity_hours, follow_up_count, reassignment_count,
    # missing_info_flag, hours_to_deadline, reopen_count
    signals = Column(JSONType, nullable=False)
    
    computed_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    # Relationships
    case = relationship("Case", back_populates="risk_assessments")


class EscalationEvent(Base):
    """
    Escalation event triggered automatically by the Sweep or manually by Operator per SRS §5.8.
    """
    __tablename__ = "escalation_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    trigger_reason = Column(SQLEnum(EscalationTrigger), nullable=False)
    escalated_to_user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    escalated_to_role = Column(String(50), nullable=True)
    escalated_by = Column(String(50), nullable=False)  # 'system' or user_id UUID
    status = Column(
        SQLEnum(EscalationStatus),
        default=EscalationStatus.OPEN,
        nullable=False,
        index=True,
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", back_populates="escalations")
    escalated_to_user = relationship("User", foreign_keys=[escalated_to_user_id])


class CommunicationDraft(Base):
    """
    AI-generated draft communication per SRS §5.9.
    Reviewed and edited by human operators before send; never auto-sent.
    """
    __tablename__ = "communication_drafts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    draft_type = Column(SQLEnum(DraftType), nullable=False)
    body = Column(Text, nullable=False)
    status = Column(
        SQLEnum(DraftStatus),
        default=DraftStatus.DRAFT,
        nullable=False,
    )
    reviewed_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    sent_message_id = Column(
        UUID(as_uuid=True),
        ForeignKey("messages.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", back_populates="communication_drafts")
    reviewer = relationship("User", foreign_keys=[reviewed_by])
    sent_message = relationship("Message", foreign_keys=[sent_message_id])
