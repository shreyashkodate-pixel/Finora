import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base


class SLA(Base):
    """
    24/7 elapsed-time SLA target model per SRS §4.3.
    Evaluated periodically by in-process APScheduler ("The Sweep").
    """
    __tablename__ = "slas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )
    
    # 24/7 wall-clock targets in UTC per SRS §4.3
    target_response_at = Column(DateTime(timezone=True), nullable=False, index=True)
    target_resolve_at = Column(DateTime(timezone=True), nullable=False, index=True)
    
    # Actual completion timestamps
    responded_at = Column(DateTime(timezone=True), nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Breach indicators
    response_breached = Column(Boolean, default=False, nullable=False, index=True)
    resolution_breached = Column(Boolean, default=False, nullable=False, index=True)
    
    paused_reason = Column(String(255), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", back_populates="sla")

    def __init__(self, **kwargs):
        kwargs.setdefault("response_breached", False)
        kwargs.setdefault("resolution_breached", False)
        super().__init__(**kwargs)
