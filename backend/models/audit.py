import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    DateTime,
    ForeignKey,
    func,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.types import JSON
from sqlalchemy.orm import relationship

from db.session import Base

JSONType = JSON().with_variant(JSONB, "postgresql")


class AuditLog(Base):
    """
    Append-only audit log entity per SRS §4 & §5.11.
    actor_id is null for system-triggered events (e.g. the Sweep).
    """
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Nullable for system actions (e.g. automated SLA escalation)
    actor_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    action = Column(String(100), nullable=False, index=True)
    target_type = Column(String(50), nullable=False, index=True)
    target_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    
    before_value = Column(JSONType, nullable=True)
    after_value = Column(JSONType, nullable=True)
    
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    # Relationships
    actor = relationship("User", foreign_keys=[actor_id])
