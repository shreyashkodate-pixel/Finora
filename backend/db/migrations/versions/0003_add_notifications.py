"""Add notifications table

Revision ID: 0003_add_notifications
Revises: 0002_add_refresh_tokens
Create Date: 2026-09-17 13:40:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0003_add_notifications"
down_revision: Union[str, None] = "0002_add_refresh_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

notification_event_type = postgresql.ENUM(
    "case_created",
    "case_assigned",
    "new_message",
    "case_resolved",
    "case_reopened",
    "sla_warning",
    "sla_breach",
    "escalation_raised",
    name="notificationeventtype",
    create_type=False,
)


def upgrade() -> None:
    # Create enum type if on postgresql
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        notification_event_type.create(bind, checkfirst=True)

    op.create_table(
        "notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "case_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cases.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("event_type", sa.Enum(
            "case_created",
            "case_assigned",
            "new_message",
            "case_resolved",
            "case_reopened",
            "sla_warning",
            "sla_breach",
            "escalation_raised",
            name="notificationeventtype",
        ), nullable=False),
        sa.Column("is_read", sa.Boolean(), default=False, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_case_id", "notifications", ["case_id"])
    op.create_index("ix_notifications_is_read", "notifications", ["is_read"])
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"])


def downgrade() -> None:
    op.drop_table("notifications")
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        notification_event_type.drop(bind, checkfirst=True)
