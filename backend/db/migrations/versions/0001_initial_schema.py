"""Initial schema for AI IT Helpdesk

Revision ID: 0001_initial_schema
Revises: 
Create Date: 2026-09-16 19:10:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial_schema"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Enable PostgreSQL Extensions (UUID & Trigram search)
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    op.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')

    # 2. Teams Table
    op.create_table(
        "teams",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("lead_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_teams_name", "teams", ["name"], unique=True)

    # 3. Users Table
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=True),
        sa.Column("auth_provider", sa.String(length=50), nullable=False, server_default="password"),
        sa.Column("oauth_subject_id", sa.String(length=255), nullable=True),
        sa.Column("role", sa.String(length=50), nullable=False, server_default="requester"),
        sa.Column("team_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("teams.id", ondelete="SET NULL"), nullable=True),
        sa.Column("site", sa.String(length=100), nullable=True),
        sa.Column("availability_status", sa.String(length=50), nullable=False, server_default="available"),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_oauth_subject_id", "users", ["oauth_subject_id"])
    op.create_index("ix_users_role", "users", ["role"])
    op.create_index("ix_users_team_id", "users", ["team_id"])

    # Add foreign key from teams.lead_id to users.id
    op.create_foreign_key("fk_teams_lead_id_users", "teams", "users", ["lead_id"], ["id"], ondelete="SET NULL")

    # 4. Cases Table
    op.create_table(
        "cases",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("reference_number", sa.String(length=32), nullable=False),
        sa.Column("type", sa.String(length=50), nullable=False, server_default="incident"),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False, server_default="new"),
        sa.Column("priority", sa.String(length=50), nullable=False, server_default="p3"),
        sa.Column("requester_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("team_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("teams.id", ondelete="SET NULL"), nullable=True),
        sa.Column("site", sa.String(length=100), nullable=True),
        sa.Column("service_id", sa.String(length=100), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_cases_reference_number", "cases", ["reference_number"], unique=True)
    op.create_index("ix_cases_type", "cases", ["type"])
    op.create_index("ix_cases_status", "cases", ["status"])
    op.create_index("ix_cases_priority", "cases", ["priority"])
    op.create_index("ix_cases_requester_id", "cases", ["requester_id"])
    op.create_index("ix_cases_owner_id", "cases", ["owner_id"])
    op.create_index("ix_cases_team_id", "cases", ["team_id"])
    op.create_index("ix_cases_created_at", "cases", ["created_at"])

    # Trigram Indexes on cases for fast search & duplicate detection per SRS §5.5 & §5.14
    op.execute("CREATE INDEX ix_cases_title_trgm ON cases USING gin (title gin_trgm_ops);")
    op.execute("CREATE INDEX ix_cases_description_trgm ON cases USING gin (description gin_trgm_ops);")

    # 5. Case Relationships Table
    op.create_table(
        "case_relationships",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("related_case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("relationship_type", sa.String(length=50), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_case_relationships_case_id", "case_relationships", ["case_id"])
    op.create_index("ix_case_relationships_related_case_id", "case_relationships", ["related_case_id"])

    # 6. Messages Table
    op.create_table(
        "messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("author_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("visibility", sa.String(length=50), nullable=False, server_default="requester_visible"),
        sa.Column("ai_generated", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_messages_case_id", "messages", ["case_id"])
    op.create_index("ix_messages_author_id", "messages", ["author_id"])
    op.create_index("ix_messages_visibility", "messages", ["visibility"])
    op.create_index("ix_messages_created_at", "messages", ["created_at"])

    # 7. Attachments Table
    op.create_table(
        "attachments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("storage_path", sa.String(length=500), nullable=False),
        sa.Column("file_type", sa.String(length=100), nullable=False),
        sa.Column("file_size", sa.Integer(), nullable=False),
        sa.Column("uploaded_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_attachments_case_id", "attachments", ["case_id"])
    op.create_index("ix_attachments_uploaded_by", "attachments", ["uploaded_by"])

    # 8. SLAs Table
    op.create_table(
        "slas",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("target_response_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("target_resolve_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("response_breached", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("resolution_breached", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("paused_reason", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_slas_case_id", "slas", ["case_id"])
    op.create_index("ix_slas_target_response_at", "slas", ["target_response_at"])
    op.create_index("ix_slas_target_resolve_at", "slas", ["target_resolve_at"])
    op.create_index("ix_slas_response_breached", "slas", ["response_breached"])
    op.create_index("ix_slas_resolution_breached", "slas", ["resolution_breached"])

    # 9. AI Triage Results Table
    op.create_table(
        "ai_triage_results",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("suggested_category", sa.String(length=100), nullable=True),
        sa.Column("suggested_severity", sa.String(length=50), nullable=True),
        sa.Column("suggested_priority", sa.String(length=50), nullable=True),
        sa.Column("confidence_level", sa.String(length=50), nullable=False, server_default="moderate"),
        sa.Column("confidence_score", sa.Float(), nullable=True),
        sa.Column("supporting_factors", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("missing_info", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("suggested_team_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("teams.id", ondelete="SET NULL"), nullable=True),
        sa.Column("recommended_next_action", sa.Text(), nullable=True),
        sa.Column("related_case_ids", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_ai_triage_results_case_id", "ai_triage_results", ["case_id"])

    # 10. Case Summaries Table
    op.create_table(
        "case_summaries",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("summary_text", sa.Text(), nullable=False),
        sa.Column("last_source_message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="SET NULL"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_case_summaries_case_id", "case_summaries", ["case_id"])

    # 11. Case Risk Assessments Table
    op.create_table(
        "case_risk_assessments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("risk_level", sa.String(length=50), nullable=False, server_default="low"),
        sa.Column("signals", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("computed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_case_risk_assessments_case_id", "case_risk_assessments", ["case_id"])
    op.create_index("ix_case_risk_assessments_risk_level", "case_risk_assessments", ["risk_level"])
    op.create_index("ix_case_risk_assessments_computed_at", "case_risk_assessments", ["computed_at"])

    # 12. Escalation Events Table
    op.create_table(
        "escalation_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("trigger_reason", sa.String(length=50), nullable=False),
        sa.Column("escalated_to_user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("escalated_to_role", sa.String(length=50), nullable=True),
        sa.Column("escalated_by", sa.String(length=50), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_escalation_events_case_id", "escalation_events", ["case_id"])
    op.create_index("ix_escalation_events_status", "escalation_events", ["status"])

    # 13. Communication Drafts Table
    op.create_table(
        "communication_drafts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("draft_type", sa.String(length=50), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False, server_default="draft"),
        sa.Column("reviewed_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("sent_message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_communication_drafts_case_id", "communication_drafts", ["case_id"])

    # 14. Audit Logs Table (Append-only)
    op.create_table(
        "audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("actor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("action", sa.String(length=100), nullable=False),
        sa.Column("target_type", sa.String(length=50), nullable=False),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("before_value", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("after_value", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_audit_logs_actor_id", "audit_logs", ["actor_id"])
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"])
    op.create_index("ix_audit_logs_target_type", "audit_logs", ["target_type"])
    op.create_index("ix_audit_logs_target_id", "audit_logs", ["target_id"])
    op.create_index("ix_audit_logs_created_at", "audit_logs", ["created_at"])

    # 15. Knowledge Articles Table
    op.create_table(
        "knowledge_articles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("state", sa.String(length=50), nullable=False, server_default="draft"),
        sa.Column("review_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_knowledge_articles_title", "knowledge_articles", ["title"])
    op.create_index("ix_knowledge_articles_owner_id", "knowledge_articles", ["owner_id"])
    op.create_index("ix_knowledge_articles_state", "knowledge_articles", ["state"])

    # 16. Approvals Table
    op.create_table(
        "approvals",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("case_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("approver_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("decision", sa.String(length=50), nullable=False, server_default="pending"),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_approvals_case_id", "approvals", ["case_id"])
    op.create_index("ix_approvals_approver_id", "approvals", ["approver_id"])
    op.create_index("ix_approvals_decision", "approvals", ["decision"])


def downgrade() -> None:
    op.drop_table("approvals")
    op.drop_table("knowledge_articles")
    op.drop_table("audit_logs")
    op.drop_table("communication_drafts")
    op.drop_table("escalation_events")
    op.drop_table("case_risk_assessments")
    op.drop_table("case_summaries")
    op.drop_table("ai_triage_results")
    op.drop_table("slas")
    op.drop_table("attachments")
    op.drop_table("messages")
    op.drop_table("case_relationships")
    op.drop_table("cases")
    op.drop_table("users")
    op.drop_table("teams")
    op.execute('DROP EXTENSION IF EXISTS "pg_trgm";')
    op.execute('DROP EXTENSION IF EXISTS "uuid-ossp";')
