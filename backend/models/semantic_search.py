import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Text,
    Float,
    DateTime,
    ForeignKey,
    JSON,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID
from db.session import Base

class SemanticEmbedding(Base):
    """
    Stores vector embeddings for cases, knowledge articles, and audit logs.
    Supports pure Python / SQLite JSON vector similarity calculation and pgvector compatibility.
    """
    __tablename__ = "semantic_embeddings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entity_type = Column(String(50), nullable=False, index=True)  # 'case', 'knowledge_article', 'audit_log'
    entity_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    content_chunk = Column(Text, nullable=False)
    embedding = Column(JSON, nullable=False)  # List[float] embedding vector (768-dim)
    metadata_json = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_semantic_embeddings_type_id", "entity_type", "entity_id"),
    )


class NLQueryLog(Base):
    """
    Logs natural language search discovery queries, synthesized AI answers, and source citations.
    """
    __tablename__ = "nl_query_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    query_text = Column(String(500), nullable=False)
    answer_text = Column(Text, nullable=False)
    citations = Column(JSON, nullable=False, default=list)  # List[Dict[str, Any]]
    confidence_score = Column(Float, nullable=False, default=1.0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
