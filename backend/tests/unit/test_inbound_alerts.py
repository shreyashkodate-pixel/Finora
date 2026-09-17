import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from core.security import create_access_token
from models.user import User, Team
from models.case import Case
from models.enums import UserRole, AlertProvider, AlertStatus, CasePriority


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_inbound_prometheus_alert_auto_incident_creation(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    """Test Prometheus critical alert auto-creates a P1 Incident."""
    payload = {
        "alerts": [
            {
                "labels": {
                    "alertname": "PostgresDatabaseConnectionExhausted",
                    "severity": "critical",
                    "instance": "db-primary-01:5432",
                },
                "annotations": {
                    "summary": "Database connection pool utilization > 95%",
                    "description": "Active connections reached 980 of 1000 max connections.",
                },
                "fingerprint": "prom-pg-pool-crit-1",
            }
        ]
    }

    res = await async_client.post(
        "/api/v1/integrations/alerts/inbound/prometheus",
        json=payload,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["provider"] == "prometheus"
    assert data["status"] == "incident_created"
    assert data["case_id"] is not None

    # Verify linked case exists
    case_res = await test_db.execute(select(Case).where(Case.id == uuid.UUID(data["case_id"])))
    created_case = case_res.scalars().first()
    assert created_case is not None
    assert "[AUTO-ALERT]" in created_case.title
    assert created_case.priority == CasePriority.P1
    assert created_case.reference_number.startswith("INC-")


@pytest.mark.asyncio
async def test_inbound_alert_deduplication_and_correlation(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    """Test rapid duplicate alerts correlate to the existing incident."""
    payload = {
        "event_title": "Redis Memory Spike Alert",
        "alert_type": "error",
        "id": "dd-mem-1029",
        "body": "Memory usage exceeded 90% threshold on node-04",
    }

    # 1. First alert creates incident
    res1 = await async_client.post(
        "/api/v1/integrations/alerts/inbound/datadog",
        json=payload,
    )
    assert res1.status_code == 201
    data1 = res1.json()
    assert data1["status"] == "incident_created"
    first_case_id = data1["case_id"]
    assert first_case_id is not None

    # 2. Second alert with identical fingerprint correlates to same case
    res2 = await async_client.post(
        "/api/v1/integrations/alerts/inbound/datadog",
        json=payload,
    )
    assert res2.status_code == 201
    data2 = res2.json()
    assert data2["status"] == "correlated"
    assert data2["case_id"] == first_case_id


@pytest.mark.asyncio
async def test_alert_rule_matching_and_acknowledgement(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    """Test custom alert rule matching and manual alert acknowledgement."""
    team = Team(name="Core Infrastructure Team")
    operator = User(
        email="operator_alert@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    lead = User(
        email="lead_alert@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([team, operator, lead])
    await test_db.commit()
    await test_db.refresh(team)
    await test_db.refresh(operator)
    await test_db.refresh(lead)

    op_token = make_token(operator)
    lead_token = make_token(lead)

    # 1. Create alert rule for Kafka alerts
    rule_res = await async_client.post(
        "/api/v1/integrations/alerts/rules",
        headers={"Authorization": f"Bearer {lead_token}"},
        json={
            "name": "Kafka Consumer Lag Routing",
            "provider": "generic",
            "match_keyword": "Kafka",
            "auto_create_incident": True,
            "incident_priority": "p2",
            "target_team_id": str(team.id),
        },
    )
    assert rule_res.status_code == 201

    # 2. Ingest generic alert matching rule
    alert_res = await async_client.post(
        "/api/v1/integrations/alerts/inbound/generic",
        json={
            "title": "Kafka Consumer Lag Exceeded Limit",
            "severity": "warning",
            "description": "Topic order-events consumer group is 50000 records behind.",
            "id": "kafka-lag-01",
        },
    )
    assert alert_res.status_code == 201
    alert_data = alert_res.json()
    assert alert_data["status"] == "incident_created"
    alert_id = alert_data["id"]

    # 3. Acknowledge alert
    ack_res = await async_client.post(
        f"/api/v1/integrations/alerts/{alert_id}/acknowledge",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert ack_res.status_code == 200
    assert ack_res.json()["status"] == "acknowledged"
    assert ack_res.json()["acknowledged_by_id"] == str(operator.id)
