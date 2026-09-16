import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
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
from models.enums import MessageVisibility


class Message(Base):
    __tablename__ = "messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    author_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    body = Column(Text, nullable=False)
    
    # requester_visible vs internal_only (strictly filtered at API layer per SRS §4 & §7.6)
    visibility = Column(
        SQLEnum(MessageVisibility),
        default=MessageVisibility.REQUESTER_VISIBLE,
        nullable=False,
        index=True,
    )
    ai_generated = Column(Boolean, default=False, nullable=False)
    
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    # Relationships
    case = relationship("Case", back_populates="messages")
    author = relationship("User", foreign_keys=[author_id])

    def __init__(self, **kwargs):
        kwargs.setdefault("visibility", MessageVisibility.REQUESTER_VISIBLE)
        kwargs.setdefault("ai_generated", False)
        super().__init__(**kwargs)
