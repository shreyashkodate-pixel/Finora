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
    assert hit["predicted_breach_probability"] >= 0.70


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
