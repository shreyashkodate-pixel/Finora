import uuid
from datetime import datetime, timezone, timedelta
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from core.config import settings
from core.security import create_access_token
from models.case import Case
from models.sla import SLA
from models.user import User, Team
from models.ai import EscalationEvent
from models.notification import Notification
from models.enums import (
    UserRole,
    CaseStatus,
    CasePriority,
    CaseType,
    EscalationTrigger,
    EscalationStatus,
    NotificationEventType,
)
from services.sweep_service import SweepService
from scheduler.manager import SweepSchedulerManager


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_sweep_sla_breach_detection_and_escalation(test_db):
    """Verify The Sweep marks overdue SLA as breached and raises MISSED_DEADLINE escalation per SRS §4.3 & §5.8."""
    now = datetime.now(timezone.utc)

    operator = User(
        email="lead_op@example.com",
        password_hash="dummy_hash",
        role=UserRole.TEAM_LEAD,
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-900001",
        title="Server completely unresponsive",
        description="Database server hung",
        status=CaseStatus.NEW,
        priority=CasePriority.P1,
        requester_id=operator.id,
        created_at=now - timedelta(hours=2),
    )
    test_db.add(case)
    await test_db.flush()

    # Response deadline was 1 hour ago
    sla = SLA(
        case_id=case.id,
        target_response_at=now - timedelta(hours=1),
        target_resolve_at=now + timedelta(hours=2),
        response_breached=False,
        resolution_breached=False,
        created_at=case.created_at,
    )
    test_db.add(sla)
    await test_db.commit()

    # Run the Sweep
    sweep = SweepService(test_db)
    summary = await sweep.run_sweep()

    assert summary["cases_evaluated"] >= 1
    assert summary["sla_breaches_detected"] >= 1
    assert summary["escalations_raised"] >= 1

    # Verify SLA was updated
    await test_db.refresh(sla)
    assert sla.response_breached is True

    # Verify EscalationEvent created
    esc_stmt = select(EscalationEvent).where(
        EscalationEvent.case_id == case.id,
        EscalationEvent.trigger_reason == EscalationTrigger.MISSED_DEADLINE,
    )
    esc_res = await test_db.execute(esc_stmt)
    escalation = esc_res.scalar_one_or_none()
    assert escalation is not None
    assert escalation.status == EscalationStatus.OPEN
    assert escalation.escalated_to_role == "team_lead"

    # Verify Notification dispatched
    notif_stmt = select(Notification).where(
        Notification.case_id == case.id,
        Notification.event_type == NotificationEventType.SLA_BREACH,
    )
    notif_res = await test_db.execute(notif_stmt)
    assert notif_res.scalar_one_or_none() is not None


@pytest.mark.asyncio
async def test_sweep_sla_warning_approaching_deadline(test_db):
    """Verify The Sweep emits SLA_WARNING when >= 80% of window has elapsed (within 20% remaining)."""
    now = datetime.now(timezone.utc)

    operator = User(
        email="warn_op@example.com",
        password_hash="dummy_hash",
        role=UserRole.TEAM_LEAD,
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.flush()

    # Case created 50 minutes ago with 60-minute window -> 50/60 = 83.3% elapsed
    case = Case(
        reference_number="INC-2026-900002",
        title="Approaching SLA deadline",
        description="Printer offline",
        status=CaseStatus.NEW,
        priority=CasePriority.P2,
        requester_id=operator.id,
        created_at=now - timedelta(minutes=50),
    )
    test_db.add(case)
    await test_db.flush()

    sla = SLA(
        case_id=case.id,
        target_response_at=now + timedelta(minutes=10),
        target_resolve_at=now + timedelta(hours=6),
        response_breached=False,
        created_at=case.created_at,
    )
    test_db.add(sla)
    await test_db.commit()

    sweep = SweepService(test_db)
    summary = await sweep.run_sweep()

    assert summary["sla_warnings_emitted"] >= 1

    # Verify SLA_WARNING notification was created
    notif_stmt = select(Notification).where(
        Notification.case_id == case.id,
        Notification.event_type == NotificationEventType.SLA_WARNING,
    )
    notif_res = await test_db.execute(notif_stmt)
    assert notif_res.scalar_one_or_none() is not None


@pytest.mark.asyncio
async def test_sweep_promotes_unacknowledged_escalation_to_manager(test_db):
    """Verify unacknowledged escalations older than 2 hours are promoted to Manager per SRS §5.8."""
    now = datetime.now(timezone.utc)

    manager = User(
        email="dept_manager@example.com",
        password_hash="dummy_hash",
        role=UserRole.MANAGER,
        email_verified=True,
    )
    operator = User(
        email="lead_user@example.com",
        password_hash="dummy_hash",
        role=UserRole.TEAM_LEAD,
        email_verified=True,
    )
    test_db.add_all([manager, operator])
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-900003",
        title="Unacknowledged escalation ticket",
        description="Complex recurring network glitch",
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P2,
        requester_id=operator.id,
        created_at=now - timedelta(hours=5),
    )
    test_db.add(case)
    await test_db.flush()

    # Escalation created 3 hours ago (> 2 hour default)
    esc = EscalationEvent(
        case_id=case.id,
        trigger_reason=EscalationTrigger.HIGH_RISK,
        escalated_to_role="team_lead",
        escalated_by="system",
        status=EscalationStatus.OPEN,
        created_at=now - timedelta(hours=3),
    )
    test_db.add(esc)
    await test_db.commit()

    sweep = SweepService(test_db)
    summary = await sweep.run_sweep()

    assert summary["escalations_promoted"] >= 1

    await test_db.refresh(esc)
    assert esc.escalated_to_role == "manager"
    assert esc.escalated_to_user_id == manager.id


@pytest.mark.asyncio
async def test_manual_operator_escalation(async_client: AsyncClient, test_db):
    """Verify human operator can manually request managerial escalation per SRS §5.8."""
    operator = User(
        email="op_manual@example.com",
        password_hash="dummy_hash",
        role=UserRole.OPERATOR,
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    token = make_token(operator)

    # 1. Create case
    case_res = await async_client.post(
        "/api/v1/cases",
        json={
            "title": "Need senior escalation",
            "description": "Cross-department firewall authorization required",
            "type": "incident",
            "priority": "p3",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = case_res.json()["id"]

    # 2. Operator requests manual escalation
    esc_res = await async_client.post(
        f"/api/v1/cases/{case_id}/escalate",
        json={"reason": "Firewall policy change requires Team Lead approval."},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert esc_res.status_code == 201
    esc_data = esc_res.json()
    assert esc_data["trigger_reason"] == "operator_requested"
    assert esc_data["status"] == "open"
    assert esc_data["escalated_by"] == str(operator.id)

    # 3. List escalations for case
    list_res = await async_client.get(
        f"/api/v1/cases/{case_id}/escalations",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert list_res.status_code == 200
    assert len(list_res.json()) >= 1


@pytest.mark.asyncio
async def test_escalation_acknowledgement_and_resolution(async_client: AsyncClient, test_db):
    """Verify Team Lead and Manager can acknowledge and resolve escalations."""
    team_lead = User(
        email="lead_ack@example.com",
        password_hash="dummy_hash",
        role=UserRole.TEAM_LEAD,
        email_verified=True,
    )
    test_db.add(team_lead)
    await test_db.commit()
    lead_token = make_token(team_lead)

    case = Case(
        reference_number="INC-2026-900004",
        title="Escalation lifecycle test",
        description="Testing acknowledge and resolve",
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P2,
        requester_id=team_lead.id,
    )
    test_db.add(case)
    await test_db.flush()

    esc = EscalationEvent(
        case_id=case.id,
        trigger_reason=EscalationTrigger.OPERATOR_REQUESTED,
        escalated_to_role="team_lead",
        escalated_by="system",
        status=EscalationStatus.OPEN,
    )
    test_db.add(esc)
    await test_db.commit()

    # 1. Team Lead acknowledges escalation
    ack_res = await async_client.patch(
        f"/api/v1/escalations/{esc.id}/acknowledge",
        headers={"Authorization": f"Bearer {lead_token}"},
    )
    assert ack_res.status_code == 200
    assert ack_res.json()["status"] == "acknowledged"

    # 2. Team Lead resolves escalation
    res_res = await async_client.patch(
        f"/api/v1/escalations/{esc.id}/resolve",
        headers={"Authorization": f"Bearer {lead_token}"},
    )
    assert res_res.status_code == 200
    assert res_res.json()["status"] == "resolved"


@pytest.mark.asyncio
async def test_on_demand_sweep_trigger_endpoint(async_client: AsyncClient, test_db):
    """Verify staff can trigger The Sweep on demand via API."""
    manager = User(
        email="sweep_admin@example.com",
        password_hash="dummy_hash",
        role=UserRole.MANAGER,
        email_verified=True,
    )
    test_db.add(manager)
    await test_db.commit()
    token = make_token(manager)

    response = await async_client.post(
        "/api/v1/sweep/trigger",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "cases_evaluated" in data
    assert "sla_warnings_emitted" in data
    assert "sla_breaches_detected" in data
    assert "escalations_raised" in data


@pytest.mark.asyncio
async def test_sweep_scheduler_manager_lifecycle(monkeypatch):
    """Verify SweepSchedulerManager correctly registers jobs and cleanly shuts down."""
    mgr = SweepSchedulerManager()

    # Enable scheduler for this unit test
    monkeypatch.setattr(settings, "ENABLE_SCHEDULER", True)
    monkeypatch.setattr(settings, "ENABLE_KEEPALIVE_PING", True)

    mgr.start()
    assert mgr.scheduler is not None
    assert mgr.scheduler.running is True

    # Check jobs registered
    jobs = mgr.scheduler.get_jobs()
    job_ids = [j.id for j in jobs]
    assert "the_sweep_periodic_job" in job_ids
    assert "render_keepalive_ping_job" in job_ids

    # Clean shutdown
    mgr.shutdown()
    assert mgr.scheduler is None
