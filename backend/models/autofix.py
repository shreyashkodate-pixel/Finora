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
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.types import JSON
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import AutoFixActionType, AutoFixStatus

JSONType = JSON().with_variant(JSONB, "postgresql")


class AutoFixAction(Base):
    """
    Level 3 Controlled Remediation action executed on a target system with human verification.
    """
    __tablename__ = "autofix_actions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action_type = Column(
        SQLEnum(AutoFixActionType),
        nullable=False,
        index=True,
    )
    parameters = Column(JSONType, nullable=False, default=dict)
    status = Column(
        SQLEnum(AutoFixStatus),
        default=AutoFixStatus.PENDING,
        nullable=False,
        index=True,
    )
    initiated_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    execution_output = Column(Text, nullable=True)
    rollback_output = Column(Text, nullable=True)
    error_message = Column(Text, nullable=True)
    executed_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case")
    initiator = relationship("User", foreign_keys=[initiated_by])
