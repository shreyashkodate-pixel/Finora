"""Add tenant isolation organization_id columns to problems, change_requests, knowledge_articles

Revision ID: 0004_add_tenant_isolation_columns
Revises: 0003_add_notifications
Create Date: 2026-09-21 14:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0004_tenant_isolation"
down_revision: Union[str, None] = "0003_add_notifications"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add organization_id to problems
    op.add_column(
        "problems",
        sa.Column(
            "organization_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("organizations.id", ondelete="CASCADE"),
            nullable=True,
        ),
    )
    op.create_index("ix_problems_organization_id", "problems", ["organization_id"])

    # 2. Add organization_id to change_requests
    op.add_column(
        "change_requests",
        sa.Column(
            "organization_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("organizations.id", ondelete="CASCADE"),
            nullable=True,
        ),
    )
    op.create_index("ix_change_requests_organization_id", "change_requests", ["organization_id"])

    # 3. Add organization_id to knowledge_articles
    op.add_column(
        "knowledge_articles",
        sa.Column(
            "organization_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("organizations.id", ondelete="CASCADE"),
            nullable=True,
        ),
    )
    op.create_index("ix_knowledge_articles_organization_id", "knowledge_articles", ["organization_id"])


def downgrade() -> None:
    op.drop_index("ix_knowledge_articles_organization_id", table_name="knowledge_articles")
    op.drop_column("knowledge_articles", "organization_id")

    op.drop_index("ix_change_requests_organization_id", table_name="change_requests")
    op.drop_column("change_requests", "organization_id")

    op.drop_index("ix_problems_organization_id", table_name="problems")
    op.drop_column("problems", "organization_id")
