import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from core.security import create_access_token
from models.audit import AuditLog
from models.case import Case
from models.enums import CasePriority, CaseStatus, CaseType, UserRole, AutoFixStatus
from models.message import Message
from models.user import User


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_autofix_propose_and_whitelist_validation(async_client: AsyncClient, test_db):
    operator = User(
        email="operator_fix@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_fix@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-8801",
        title="Redis caching layer unresponsive",
        description="Users experiencing latency on session reads.",
        type=CaseType.INCIDENT,
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P2,
        requester_id=requester.id,
        site="HQ",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)
    req_token = make_token(requester)

    # 1. Propose valid whitelisted service restart
    resp = await async_client.post(
        f"/api/v1/autofix/propose/{case.id}",
        json={
            "action_type": "service_restart",
            "parameters": {"service_name": "redis"},
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "pending"
    assert data["action_type"] == "service_restart"

    # 2. Reject non-whitelisted service
    bad_resp = await async_client.post(
        f"/api/v1/autofix/propose/{case.id}",
        json={
            "action_type": "service_restart",
            "parameters": {"service_name": "unknown_crypto_daemon"},
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert bad_resp.status_code == 400
    assert bad_resp.json()["error"]["code"] == "INVALID_SERVICE_NAME"

    # 3. Reject requester attempting to propose
    forbid_resp = await async_client.post(
        f"/api/v1/autofix/propose/{case.id}",
        json={
            "action_type": "service_restart",
            "parameters": {"service_name": "redis"},
        },
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert forbid_resp.status_code == 403


@pytest.mark.asyncio
async def test_autofix_execute_and_rollback_flow(async_client: AsyncClient, test_db):
    operator = User(
        email="operator_exec@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_exec@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-8802",
        title="Active Directory User Account Locked",
        description="Repeated wrong password attempts.",
        type=CaseType.SERVICE_REQUEST,
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P3,
        requester_id=requester.id,
        site="HQ",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)

    # 1. Propose account unlock
    prop_resp = await async_client.post(
        f"/api/v1/autofix/propose/{case.id}",
        json={
            "action_type": "account_unlock",
            "parameters": {"username": "shreyash.k"},
        },
        headers={"Authorization": f"Bearer {op_token}"},
    )
    action_id = prop_resp.json()["id"]

    # 2. Execute auto-fix
    exec_resp = await async_client.post(
        f"/api/v1/autofix/execute/{action_id}",
        json={"dry_run": False, "confirmed": True},
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert exec_resp.status_code == 200
    exec_data = exec_resp.json()
    assert exec_data["status"] == "success"
    assert "LDAP Directory account 'shreyash.k' unlocked" in exec_data["execution_output"]

    # Verify internal case message created
    msg_stmt = select(Message).where(Message.case_id == case.id)
    msg_res = await test_db.execute(msg_stmt)
    messages = list(msg_res.scalars().all())
    assert len(messages) == 1
    assert "Automated Remediation Executed" in messages[0].body

    # 3. Rollback auto-fix
    rb_resp = await async_client.post(
        f"/api/v1/autofix/rollback/{action_id}",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert rb_resp.status_code == 200
    assert rb_resp.json()["status"] == "rolled_back"

    # 4. List actions for case
    list_resp = await async_client.get(
        f"/api/v1/autofix/case/{case.id}",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1
