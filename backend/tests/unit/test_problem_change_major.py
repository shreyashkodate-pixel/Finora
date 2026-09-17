import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from core.security import create_access_token
from models.audit import AuditLog
from models.case import Case
from models.enums import (
    CasePriority,
    CaseStatus,
    CaseType,
    UserRole,
    ProblemStatus,
    ChangeType,
    ChangeStatus,
    MajorIncidentStatus,
)
from models.problem_change import (
    Problem,
    ProblemCaseLink,
    KnownError,
    ChangeRequest,
    MajorIncident,
    MajorIncidentTimeline,
)
from models.user import User


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_problem_lifecycle_and_linking(async_client: AsyncClient, test_db):
    """Test creating a problem, linking a case, and publishing a known error."""
    operator = User(
        email="operator_prob@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_prob@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-0991",
        title="VPN Connection Drops repeatedly",
        description="VPN Gateway dropped 50 users.",
        type=CaseType.INCIDENT,
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P2,
        requester_id=requester.id,
        site="Campus North",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)

    # 1. Create Problem
    prob_resp = await async_client.post(
        "/api/v1/problems",
        json={
            "title": "Global VPN Gateway MTU Mismatch",
            "description": "Packet fragmentation leading to dropped TCP sessions.",
            "priority": "p2",
            "root_cause": "Firmware 12.4 MTU default set to 1420 instead of 1500.",
            "workaround": "Set client adapter MTU to 1400 manually.",
            "case_ids": [str(case.id)],
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert prob_resp.status_code == 201
    prob_data = prob_resp.json()
    prob_id = prob_data["id"]
    assert prob_data["problem_number"].startswith("PRB-")
    assert prob_data["status"] == "open"
    assert len(prob_data["case_links"]) == 1

    # 2. Get Problem
    get_resp = await async_client.get(
        f"/api/v1/problems/{prob_id}",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert get_resp.status_code == 200
    assert get_resp.json()["title"] == "Global VPN Gateway MTU Mismatch"

    # 3. Publish Known Error
    ke_resp = await async_client.post(
        f"/api/v1/problems/{prob_id}/known-error",
        json={
            "title": "KEDB: VPN Drops on Mac/Linux",
            "symptoms": "Session terminates after 10 minutes of heavy traffic.",
            "workaround": "Run `sudo ifconfig en0 mtu 1400`",
            "permanent_fix": "Upgrade gateway firmware to 12.5 in next change window.",
            "published": True,
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert ke_resp.status_code == 201
    ke_data = ke_resp.json()
    assert ke_data["title"] == "KEDB: VPN Drops on Mac/Linux"

    # 4. Update problem status
    patch_resp = await async_client.patch(
        f"/api/v1/problems/{prob_id}",
        json={"status": "resolved"},
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["status"] == "resolved"


@pytest.mark.asyncio
async def test_change_management_cab_workflow(async_client: AsyncClient, test_db):
    """Test Change Request creation and CAB approval decision."""
    operator = User(
        email="operator_chg@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    manager = User(
        email="manager_cab@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="HQ",
        email_verified=True,
    )
    test_db.add_all([operator, manager])
    await test_db.commit()

    op_token = make_token(operator)
    mgr_token = make_token(manager)

    # 1. Create Normal Change Request
    chg_resp = await async_client.post(
        "/api/v1/changes",
        json={
            "title": "Upgrade Core Router BGP Configuration",
            "description": "Deploy route reflector cluster.",
            "reason": "Reduce convergence time during link failover.",
            "risk_level": "moderate",
            "change_type": "normal",
            "implementation_plan": "1. Apply BGP template on router-01. 2. Verify peer routes.",
            "test_plan": "Ping upstream gateways and execute traceroute tests.",
            "rollback_plan": "Restore backup config archive from /etc/network/backup.tar.gz",
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert chg_resp.status_code == 201
    chg_data = chg_resp.json()
    chg_id = chg_data["id"]
    assert chg_data["change_number"].startswith("CHG-")
    assert chg_data["status"] == "pending_cab"

    # 2. CAB Decision by Manager
    cab_resp = await async_client.post(
        f"/api/v1/changes/{chg_id}/cab-decision",
        json={
            "approved": True,
            "feedback": "Approved for Sunday maintenance window 02:00-04:00 UTC.",
        },
        headers={"Authorization": f"Bearer {mgr_token}"},
    )
    assert cab_resp.status_code == 200
    assert cab_resp.json()["status"] == "approved"
    assert cab_resp.json()["cab_feedback"] == "Approved for Sunday maintenance window 02:00-04:00 UTC."

    # 3. Advance to implementing then completed
    status_resp = await async_client.patch(
        f"/api/v1/changes/{chg_id}/status?new_status=implementing",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert status_resp.status_code == 200
    assert status_resp.json()["status"] == "implementing"


@pytest.mark.asyncio
async def test_major_incident_declaration_and_war_room(async_client: AsyncClient, test_db):
    """Test declaring a Major Incident on P1 outage, adding timeline updates, and resolving."""
    operator = User(
        email="commander_maj@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_maj@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-9999",
        title="Production Database Cluster Down",
        description="All API requests returning 500.",
        type=CaseType.INCIDENT,
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P1,
        requester_id=requester.id,
        site="HQ",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)

    # 1. Declare Major Incident
    maj_resp = await async_client.post(
        "/api/v1/major-incidents",
        json={
            "case_id": str(case.id),
            "title": "P1 Global Database Outage",
            "bridge_url": "https://meet.google.com/maj-outage-bridge",
            "impact_summary": "100% of customer checkout requests failing.",
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert maj_resp.status_code == 201
    maj_data = maj_resp.json()
    maj_id = maj_data["id"]
    assert maj_data["incident_number"].startswith("MAJ-")
    assert maj_data["status"] == "declared"
    assert len(maj_data["timeline_events"]) == 1

    # 2. Add Timeline Event
    tl_resp = await async_client.post(
        f"/api/v1/major-incidents/{maj_id}/timeline",
        json={
            "summary": "Database failover initiated",
            "details": "Promoting standby replica to primary cluster leader.",
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert tl_resp.status_code == 201
    assert tl_resp.json()["summary"] == "Database failover initiated"

    # 3. Mitigate & Resolve
    up_resp = await async_client.patch(
        f"/api/v1/major-incidents/{maj_id}",
        json={
            "status": "resolved",
            "executive_summary": "Replica promoted in 12 minutes. Zero data loss verified.",
            "post_mortem_url": "https://wiki.finora.internal/postmortem/maj-2026-0001",
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert up_resp.status_code == 200
    assert up_resp.json()["status"] == "resolved"
    assert up_resp.json()["executive_summary"] is not None
