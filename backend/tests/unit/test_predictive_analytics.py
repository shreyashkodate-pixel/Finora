import uuid
from datetime import datetime, timezone, timedelta
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import create_access_token
from models.user import User, Team
from models.case import Case
from models.sla import SLA
from models.enums import UserRole, CaseType, CasePriority, CaseStatus


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_workload_forecast_generation(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    lead = User(
        email="lead_forecast@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(lead)
    await test_db.commit()
    await test_db.refresh(lead)
    token = make_token(lead)

    res = await async_client.get(
        "/api/v1/analytics/predictive/workload?horizon_days=14",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["horizon_days"] == 14
    assert data["predicted_total_cases"] > 0
    assert "category_breakdown" in data
    assert "confidence_interval" in data
    assert len(data["recommendation"]) > 10


@pytest.mark.asyncio
async def test_predictive_risk_forecast(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_risk_pred@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    await test_db.refresh(operator)
    token = make_token(operator)

    now = datetime.now(timezone.utc)
    # Create P1 case with tight SLA
    crit_case = Case(
        reference_number="INC-2026-999001",
        title="Payment Gateway Timeout Incident",
        description="Production payment processing is unresponsive.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P1,
        status=CaseStatus.ASSIGNED,
        requester_id=operator.id,
        created_at=now - timedelta(hours=3),
    )
    test_db.add(crit_case)
    await test_db.flush()

    # SLA window almost expired (resolution target was 4 hours from creation, so 1 hour remaining)
    sla = SLA(
        case_id=crit_case.id,
        target_response_at=now - timedelta(hours=2),
        target_resolve_at=now + timedelta(minutes=45),
        resolution_breached=False,
    )
    test_db.add(sla)
    await test_db.commit()

    res = await async_client.get(
        "/api/v1/analytics/predictive/risk-forecast",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["total_at_risk_cases"] >= 1
    high_risk_refs = [c["reference_number"] for c in data["high_risk_cases"]]
    assert "INC-2026-999001" in high_risk_refs
    hit = [c for c in data["high_risk_cases"] if c["reference_number"] == "INC-2026-999001"][0]
    assert hit["risk_score"] >= 0.70


@pytest.mark.asyncio
async def test_team_capacity_overview(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    lead = User(
        email="manager_cap@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="Campus North",
        email_verified=True,
    )
    team = Team(name="Cloud Platform Reliability Team")
    test_db.add_all([lead, team])
    await test_db.commit()
    await test_db.refresh(lead)
    await test_db.refresh(team)

    op1 = User(
        email="op_cap1@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        team_id=team.id,
        email_verified=True,
    )
    test_db.add(op1)
    await test_db.commit()

    token = make_token(lead)
    res = await async_client.get(
        "/api/v1/analytics/capacity/teams",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["total_teams"] >= 1
    t_match = [t for t in data["teams"] if t["team_id"] == str(team.id)]
    assert len(t_match) == 1
    assert t_match[0]["active_operators"] == 1
    assert "burnout_risk" in t_match[0]


@pytest.mark.asyncio
async def test_predictive_analytics_tenant_isolation(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    from models.organization import Organization

    org_a = Organization(name="Tenant Alpha", slug=f"tenant-alpha-{uuid.uuid4().hex[:6]}")
    org_b = Organization(name="Tenant Beta", slug=f"tenant-beta-{uuid.uuid4().hex[:6]}")
    test_db.add_all([org_a, org_b])
    await test_db.flush()

    user_a = User(
        email=f"manager_a_{uuid.uuid4().hex[:6]}@alpha.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        organization_id=org_a.id,
        email_verified=True,
    )
    user_b = User(
        email=f"manager_b_{uuid.uuid4().hex[:6]}@beta.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        organization_id=org_b.id,
        email_verified=True,
    )
    test_db.add_all([user_a, user_b])
    await test_db.flush()

    team_a = Team(name=f"Alpha SRE {uuid.uuid4().hex[:6]}", organization_id=org_a.id)
    team_b = Team(name=f"Beta DevSecOps {uuid.uuid4().hex[:6]}", organization_id=org_b.id)
    test_db.add_all([team_a, team_b])
    await test_db.flush()

    now = datetime.now(timezone.utc)
    # Case in Org A
    case_a = Case(
        reference_number=f"INC-A-{uuid.uuid4().hex[:6]}",
        title="Alpha DB Slowdown",
        description="Alpha latency high",
        type=CaseType.INCIDENT,
        priority=CasePriority.P1,
        status=CaseStatus.ASSIGNED,
        requester_id=user_a.id,
        team_id=team_a.id,
        organization_id=org_a.id,
        created_at=now - timedelta(hours=3),
    )
    # Case in Org B with imminent breach
    case_b = Case(
        reference_number=f"INC-B-{uuid.uuid4().hex[:6]}",
        title="Beta Security Alert Breach",
        description="Beta critical firewall leak",
        type=CaseType.INCIDENT,
        priority=CasePriority.P1,
        status=CaseStatus.ASSIGNED,
        requester_id=user_b.id,
        team_id=team_b.id,
        organization_id=org_b.id,
        created_at=now - timedelta(hours=3),
    )
    test_db.add_all([case_a, case_b])
    await test_db.flush()

    sla_a = SLA(
        case_id=case_a.id,
        target_response_at=now - timedelta(hours=2),
        target_resolve_at=now + timedelta(minutes=30),
        resolution_breached=False,
    )
    sla_b = SLA(
        case_id=case_b.id,
        target_response_at=now - timedelta(hours=2),
        target_resolve_at=now + timedelta(minutes=15),
        resolution_breached=False,
    )
    test_db.add_all([sla_a, sla_b])
    await test_db.commit()

    token_a = make_token(user_a)
    token_b = make_token(user_b)

    # 1. Test SLA Risk Isolation
    res_a_risk = await async_client.get(
        "/api/v1/analytics/predictive/risk-forecast",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert res_a_risk.status_code == 200
    refs_a = [c["reference_number"] for c in res_a_risk.json()["high_risk_cases"]]
    assert case_a.reference_number in refs_a
    assert case_b.reference_number not in refs_a

    # 2. Test Team Capacity Isolation
    res_a_cap = await async_client.get(
        "/api/v1/analytics/capacity/teams",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert res_a_cap.status_code == 200
    team_ids_a = [t["team_id"] for t in res_a_cap.json()["teams"]]
    assert str(team_a.id) in team_ids_a
    assert str(team_b.id) not in team_ids_a

    res_b_cap = await async_client.get(
        "/api/v1/analytics/capacity/teams",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert res_b_cap.status_code == 200
    team_ids_b = [t["team_id"] for t in res_b_cap.json()["teams"]]
    assert str(team_b.id) in team_ids_b
    assert str(team_a.id) not in team_ids_b


@pytest.mark.asyncio
async def test_predictive_analytics_rbac_matrix(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    roles_and_expected = [
        (UserRole.REQUESTER, 403, 403, 403),
        (UserRole.OPERATOR, 403, 200, 403),
        (UserRole.TEAM_LEAD, 200, 200, 200),
        (UserRole.MANAGER, 200, 200, 200),
        (UserRole.ADMINISTRATOR, 200, 200, 200),
    ]

    for role, exp_workload, exp_risk, exp_cap in roles_and_expected:
        user = User(
            email=f"user_{role.value}_{uuid.uuid4().hex[:6]}@example.com",
            password_hash="hash",
            role=role,
            email_verified=True,
        )
        test_db.add(user)
        await test_db.commit()
        await test_db.refresh(user)
        token = make_token(user)

        res_w = await async_client.get(
            "/api/v1/analytics/predictive/workload",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert res_w.status_code == exp_workload, f"Role {role} workload failed: expected {exp_workload}, got {res_w.status_code}"

        res_r = await async_client.get(
            "/api/v1/analytics/predictive/risk-forecast",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert res_r.status_code == exp_risk, f"Role {role} risk failed: expected {exp_risk}, got {res_r.status_code}"

        res_c = await async_client.get(
            "/api/v1/analytics/capacity/teams",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert res_c.status_code == exp_cap, f"Role {role} capacity failed: expected {exp_cap}, got {res_c.status_code}"

