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
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.enums import KnowledgeState, ApprovalDecision


class KnowledgeArticle(Base):
    """
    Manually authored knowledge article per SRS §4 & §6.
    """
    __tablename__ = "knowledge_articles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False, index=True)
    body = Column(Text, nullable=False)
    owner_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    state = Column(
        SQLEnum(KnowledgeState),
        default=KnowledgeState.DRAFT,
        nullable=False,
        index=True,
    )
    review_date = Column(DateTime(timezone=True), nullable=True)
    source_case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="SET NULL"),
        nullable=True,
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

    # Relationships
    owner = relationship("User", foreign_keys=[owner_id])
    source_case = relationship("Case", foreign_keys=[source_case_id])


class Approval(Base):
    """
    Business approval entity for Service Requests per SRS §4.
    """
    __tablename__ = "approvals"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    case_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    approver_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    decision = Column(
        SQLEnum(ApprovalDecision),
        default=ApprovalDecision.PENDING,
        nullable=False,
        index=True,
    )
    reason = Column(Text, nullable=True)
    decided_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    case = relationship("Case", back_populates="approvals")
    approver = relationship("User", foreign_keys=[approver_id])
