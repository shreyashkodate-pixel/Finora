import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from core.config import settings
from core.security import create_access_token
from models.user import User, Team
from models.case import Case
from models.organization import Organization
from models.alert import InboundAlert, AlertRule
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


@pytest.mark.asyncio
async def test_webhook_authentication_enforcement(
    async_client: AsyncClient,
    test_db: AsyncSession,
    monkeypatch,
):
    """Test webhook authentication rejects invalid secrets and accepts valid credentials."""
    monkeypatch.setattr(settings, "ALERT_WEBHOOK_SECRET", "super_secret_webhook_key_123")

    payload = {
        "title": "Unauthenticated Alert Attempt",
        "severity": "high",
        "description": "Attempting ingress without secret",
        "id": "unauth-1",
    }

    # 1. Missing authentication credentials -> 401
    res_no_auth = await async_client.post(
        "/api/v1/integrations/alerts/inbound/generic",
        json=payload,
    )
    assert res_no_auth.status_code == 401
    assert res_no_auth.json()["error"]["code"] == "WEBHOOK_UNAUTHORIZED"

    # 2. Invalid secret in header -> 401
    res_bad_auth = await async_client.post(
        "/api/v1/integrations/alerts/inbound/generic",
        headers={"X-Webhook-Secret": "wrong_secret"},
        json=payload,
    )
    assert res_bad_auth.status_code == 401

    # 3. Valid secret in X-Webhook-Secret header -> 201
    res_header_auth = await async_client.post(
        "/api/v1/integrations/alerts/inbound/generic",
        headers={"X-Webhook-Secret": "super_secret_webhook_key_123"},
        json=payload,
    )
    assert res_header_auth.status_code == 201
    assert res_header_auth.json()["title"] == "Unauthenticated Alert Attempt"

    # 4. Valid secret in query parameter -> 201
    res_query_auth = await async_client.post(
        "/api/v1/integrations/alerts/inbound/generic?secret=super_secret_webhook_key_123",
        json={"title": "Query Auth Alert", "severity": "info", "id": "query-auth-1"},
    )
    assert res_query_auth.status_code == 201


@pytest.mark.asyncio
async def test_provider_specific_webhook_auth(
    async_client: AsyncClient,
    test_db: AsyncSession,
    monkeypatch,
):
    """Test provider-specific secret headers for Datadog, Sentry, CloudWatch, and Prometheus."""
    monkeypatch.setattr(settings, "DATADOG_WEBHOOK_SECRET", "dd_secret_999")
    monkeypatch.setattr(settings, "SENTRY_WEBHOOK_SECRET", "sentry_secret_888")

    # Datadog with matching header
    res_dd = await async_client.post(
        "/api/v1/integrations/alerts/inbound/datadog",
        headers={"X-Datadog-Webhook-Secret": "dd_secret_999"},
        json={"event_title": "DD CPU Alert", "alert_type": "error", "id": "dd-test-1"},
    )
    assert res_dd.status_code == 201

    # Sentry with matching header
    res_sentry = await async_client.post(
        "/api/v1/integrations/alerts/inbound/sentry",
        headers={"X-Sentry-Token": "sentry_secret_888"},
        json={"event": {"title": "Sentry ZeroDivisionError"}, "level": "error", "id": "sentry-test-1"},
    )
    assert res_sentry.status_code == 201


@pytest.mark.asyncio
async def test_tenant_isolation_alerts_and_rules(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    """Verify Tenant A cannot list, acknowledge, or target Tenant B resources."""
    org_a = Organization(name="Tenant Alpha Corp", slug="alpha-corp")
    org_b = Organization(name="Tenant Beta LLC", slug="beta-llc")
    test_db.add_all([org_a, org_b])
    await test_db.commit()
    await test_db.refresh(org_a)
    await test_db.refresh(org_b)

    team_b = Team(name="Beta DevOps", organization_id=org_b.id)
    user_a_lead = User(
        email="lead_a@alpha.corp",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Alpha HQ",
        email_verified=True,
        organization_id=org_a.id,
    )
    user_b_operator = User(
        email="op_b@beta.llc",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Beta HQ",
        email_verified=True,
        organization_id=org_b.id,
    )
    test_db.add_all([team_b, user_a_lead, user_b_operator])
    await test_db.commit()
    await test_db.refresh(team_b)
    await test_db.refresh(user_a_lead)
    await test_db.refresh(user_b_operator)

    token_a = make_token(user_a_lead)
    token_b = make_token(user_b_operator)

    # 1. Ingest alert for Tenant B
    alert_b_res = await async_client.post(
        f"/api/v1/integrations/alerts/inbound/generic?org_id={org_b.id}",
        json={"title": "Beta Secret Database Incident", "severity": "critical", "id": "beta-db-1"},
    )
    assert alert_b_res.status_code == 201
    alert_b_id = alert_b_res.json()["id"]

    # 2. Ingest alert for Tenant A
    alert_a_res = await async_client.post(
        f"/api/v1/integrations/alerts/inbound/generic?org_id={org_a.id}",
        json={"title": "Alpha Gateway Outage", "severity": "critical", "id": "alpha-gw-1"},
    )
    assert alert_a_res.status_code == 201

    # 3. User A queries alerts -> must NOT see Tenant B alerts
    list_a_res = await async_client.get(
        "/api/v1/integrations/alerts",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert list_a_res.status_code == 200
    alerts_a = list_a_res.json()
    titles_a = [a["title"] for a in alerts_a]
    assert "Alpha Gateway Outage" in titles_a
    assert "Beta Secret Database Incident" not in titles_a

    # 4. User A attempts to acknowledge Tenant B alert -> 403 Forbidden
    cross_ack_res = await async_client.post(
        f"/api/v1/integrations/alerts/{alert_b_id}/acknowledge",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert cross_ack_res.status_code == 403
    assert cross_ack_res.json()["error"]["code"] == "FORBIDDEN"

    # 5. User A attempts to create rule targeting Tenant B's team -> 403 Forbidden
    cross_rule_res = await async_client.post(
        "/api/v1/integrations/alerts/rules",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "name": "Malicious Cross-Tenant Rule",
            "provider": "generic",
            "target_team_id": str(team_b.id),
        },
    )
    assert cross_rule_res.status_code == 403


@pytest.mark.asyncio
async def test_server_side_rbac_alert_and_rules(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    """Test RBAC restrictions across Requester, Operator, and Team Lead roles."""
    requester = User(
        email="requester_alert@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus South",
        email_verified=True,
    )
    operator = User(
        email="operator_rbac@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus South",
        email_verified=True,
    )
    lead = User(
        email="lead_rbac@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Campus South",
        email_verified=True,
    )
    test_db.add_all([requester, operator, lead])
    await test_db.commit()
    await test_db.refresh(requester)
    await test_db.refresh(operator)
    await test_db.refresh(lead)

    req_token = make_token(requester)
    op_token = make_token(operator)
    lead_token = make_token(lead)

    # 1. Requester blocked from GET alerts -> 403
    req_alert_res = await async_client.get(
        "/api/v1/integrations/alerts",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert req_alert_res.status_code == 403

    # 2. Requester blocked from GET rules -> 403
    req_rules_res = await async_client.get(
        "/api/v1/integrations/alerts/rules",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert req_rules_res.status_code == 403

    # 3. Operator blocked from POST rules -> 403
    op_create_res = await async_client.post(
        "/api/v1/integrations/alerts/rules",
        headers={"Authorization": f"Bearer {op_token}"},
        json={"name": "Operator Disallowed Rule", "provider": "generic"},
    )
    assert op_create_res.status_code == 403

    # 4. Team Lead authorized to POST rules -> 201
    lead_create_res = await async_client.post(
        "/api/v1/integrations/alerts/rules",
        headers={"Authorization": f"Bearer {lead_token}"},
        json={"name": "Team Lead Authorized Rule", "provider": "generic"},
    )
    assert lead_create_res.status_code == 201
    assert lead_create_res.json()["name"] == "Team Lead Authorized Rule"

