
import uuid
from datetime import datetime, timezone
import pytest

from models.enums import (
    UserRole,
    AuthProvider,
    AvailabilityStatus,
    CaseType,
    CaseStatus,
    CasePriority,
    MessageVisibility,
    ConfidenceLevel,
    RiskLevel,
    EscalationTrigger,
    EscalationStatus,
    DraftType,
    DraftStatus,
    ApprovalDecision,
    KnowledgeState,
)
from models.user import User, Team
from models.case import Case, CaseRelationship
from models.message import Message
from models.attachment import Attachment
from models.sla import SLA
from models.ai import (
    AITriageResult,
    CaseSummary,
    CaseRiskAssessment,
    EscalationEvent,
    CommunicationDraft,
)
from models.audit import AuditLog
from models.knowledge import KnowledgeArticle, Approval


def test_user_model_defaults_and_oauth():
    """Verify User model defaults and nullable password_hash for OAuth accounts per SRS v3.3."""
    user = User(
        email="requester@example.com",
        auth_provider=AuthProvider.GOOGLE,
        oauth_subject_id="google-sub-123456",
        password_hash=None,  # Nullable for OAuth accounts
    )
    assert user.role == UserRole.REQUESTER
    assert user.availability_status == AvailabilityStatus.AVAILABLE
    assert user.email_verified is False
    assert user.password_hash is None
    assert user.auth_provider == AuthProvider.GOOGLE


def test_case_model_defaults_and_optimistic_locking():
    """Verify Case model defaults and version column per SRS §7.12."""
    requester_id = uuid.uuid4()
    ticket = Case(
        reference_number="INC-2026-000001",
        title="Network connectivity drop in Lab 3",
        description="The primary switch in Lab 3 dropped all connections.",
        requester_id=requester_id,
    )
    assert ticket.type == CaseType.INCIDENT
    assert ticket.status == CaseStatus.NEW
    assert ticket.priority == CasePriority.P3
    assert ticket.version == 1  # Default optimistic locking version


def test_sla_model_24_7_fields():
    """Verify SLA model stores 24/7 target timestamps and breach flags."""
    case_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    sla = SLA(
        case_id=case_id,
        target_response_at=now,
        target_resolve_at=now,
    )
    assert sla.response_breached is False
    assert sla.resolution_breached is False
    assert sla.paused_reason is None


def test_ai_triage_result_confidence_level():
    """Verify AITriageResult stores ConfidenceLevel enum and internal float score."""
    case_id = uuid.uuid4()
    triage = AITriageResult(
        case_id=case_id,
        suggested_category="Network",
        suggested_severity="High",
        suggested_priority=CasePriority.P2,
        confidence_level=ConfidenceLevel.HIGH,
        confidence_score=0.92,
        supporting_factors={"matched_terms": ["switch", "dropped connections"]},
        missing_info=["device_ip", "switch_port"],
        recommended_next_action="Dispatch on-site technician to check rack 4",
    )
    assert triage.confidence_level == ConfidenceLevel.HIGH
    assert triage.confidence_score == 0.92
    assert "device_ip" in triage.missing_info


def test_case_risk_assessment_signals():
    """Verify CaseRiskAssessment stores risk enum and structured signals."""
    case_id = uuid.uuid4()
    risk = CaseRiskAssessment(
        case_id=case_id,
        risk_level=RiskLevel.HIGH,
        signals={
            "inactivity_hours": 12.5,
            "follow_up_count": 3,
            "reassignment_count": 2,
            "missing_info_flag": True,
            "hours_to_deadline": 1.2,
            "reopen_count": 1,
        },
    )
    assert risk.risk_level == RiskLevel.HIGH
    assert risk.signals["follow_up_count"] == 3


def test_audit_log_system_actor_nullable():
    """Verify AuditLog allows null actor_id for background Sweep actions per SRS §4."""
    audit = AuditLog(
        actor_id=None,  # System-triggered action
        action="AUTOMATIC_SLA_WARNING",
        target_type="case",
        target_id=uuid.uuid4(),
        before_value={"breached": False},
        after_value={"breached": True},
    )
    assert audit.actor_id is None
    assert audit.action == "AUTOMATIC_SLA_WARNING"


def test_message_visibility_control():
    """Verify Message visibility defaults to requester_visible."""
    case_id = uuid.uuid4()
    author_id = uuid.uuid4()
    msg = Message(
        case_id=case_id,
        author_id=author_id,
        body="We are currently investigating the issue.",
    )
    assert msg.visibility == MessageVisibility.REQUESTER_VISIBLE
    assert msg.ai_generated is False
