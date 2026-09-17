import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Text,
    Boolean,
    DateTime,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import AlertProvider, AlertStatus, CasePriority


class InboundAlert(Base):
    """
    Stores external monitoring alerts received from APM and observability systems.
    """
    __tablename__ = "inbound_alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider = Column(SQLEnum(AlertProvider), nullable=False, default=AlertProvider.GENERIC, index=True)
    external_alert_id = Column(String(255), nullable=True, index=True)
    title = Column(String(255), nullable=False)
    severity = Column(String(50), nullable=False, default="warning", index=True)  # critical, high, warning, info
    description = Column(Text, nullable=True)
    fingerprint = Column(String(255), nullable=False, index=True)
    status = Column(SQLEnum(AlertStatus), nullable=False, default=AlertStatus.RECEIVED, index=True)
    raw_payload = Column(JSON, nullable=False, default=dict)
    
    # Linked incident created by automation or manual triage
    case_id = Column(UUID(as_uuid=True), ForeignKey("cases.id", ondelete="SET NULL"), nullable=True, index=True)
    
    # Acknowledgement metadata
    acknowledged_at = Column(DateTime(timezone=True), nullable=True)
    acknowledged_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    case = relationship("Case", foreign_keys=[case_id], lazy="joined")
    acknowledged_by = relationship("User", foreign_keys=[acknowledged_by_id], lazy="joined")

    __table_args__ = (
        Index("ix_inbound_alerts_fp_created", "fingerprint", "created_at"),
    )


class AlertRule(Base):
    """
    Defines automation rules for routing, priority mapping, and auto-incident creation.
    """
    __tablename__ = "alert_rules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False, unique=True)
    provider = Column(SQLEnum(AlertProvider), nullable=False, default=AlertProvider.GENERIC, index=True)
    match_severity = Column(String(50), nullable=True)  # e.g. "critical"
    match_keyword = Column(String(100), nullable=True)   # string in title/description
    auto_create_incident = Column(Boolean, default=True, nullable=False)
    incident_priority = Column(SQLEnum(CasePriority), nullable=False, default=CasePriority.P2)
    target_team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="SET NULL"), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    target_team = relationship("Team", foreign_keys=[target_team_id], lazy="joined")
