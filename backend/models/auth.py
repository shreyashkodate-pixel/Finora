import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    DateTime,
    ForeignKey,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base


class RefreshToken(Base):
    """
    Persisted refresh tokens for session management, rotation, and revocation per SRS §7.4.
    Stores a hash of the refresh token, not the plaintext token.
    """
    __tablename__ = "refresh_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash = Column(String(255), nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    user_agent = Column(String(255), nullable=True)
    ip_address = Column(String(50), nullable=True)

    # Relationships
    user = relationship("User", foreign_keys=[user_id])
