import uuid
from datetime import datetime, timezone, timedelta
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from models.case import Case
from models.user import User
from models.sla import SLA
from models.enums import UserRole, CaseStatus, CaseType, CasePriority, MessageVisibility, RelationshipType
from core.security import create_access_token


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_create_case_and_reference_number(async_client: AsyncClient, test_db):
    """Verify case creation auto-generates reference number and 24/7 SLA targets."""
    user = User(
        email="req1@example.com",
        password_hash="dummy_hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    payload = {
        "title": "VPN connection drops repeatedly",
        "description": "Every 10 minutes the AnyConnect client disconnects.",
        "type": "incident",
        "priority": "p2",
    }
    response = await async_client.post(
        "/api/v1/cases",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "VPN connection drops repeatedly"
    assert data["status"] == "new"
    assert data["priority"] == "p2"
    assert data["type"] == "incident"
    assert data["site"] == "Campus North"
    assert data["version"] == 1

    current_year = datetime.now(timezone.utc).year
    assert data["reference_number"] == f"INC-{current_year}-000001"

    # SLA check for P2: response +1h, resolve +8h
    assert data["sla"] is not None
    assert data["sla"]["response_breached"] is False
    assert data["sla"]["resolution_breached"] is False


@pytest.mark.asyncio
async def test_sequential_reference_numbers(async_client: AsyncClient, test_db):
    """Verify sequential reference numbers per case type and year."""
    user = User(
        email="req2@example.com",
        password_hash="dummy_hash",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    current_year = datetime.now(timezone.utc).year
    res1 = await async_client.post(
        "/api/v1/cases",
        json={"title": "Req 1", "description": "Desc 1", "type": "service_request"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res1.status_code == 201
    assert res1.json()["reference_number"] == f"REQ-{current_year}-000001"

    res2 = await async_client.post(
        "/api/v1/cases",
        json={"title": "Req 2", "description": "Desc 2", "type": "service_request"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res2.status_code == 201
    assert res2.json()["reference_number"] == f"REQ-{current_year}-000002"


@pytest.mark.asyncio
async def test_list_cases_requester_isolation(async_client: AsyncClient, test_db):
    """Verify Requesters can only list their own cases per SRS §2.2 & §7.6."""
    user_a = User(email="user_a@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    user_b = User(email="user_b@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    test_db.add_all([user_a, user_b])
    await test_db.commit()

    token_a = make_token(user_a)
    token_b = make_token(user_b)

    # User A creates case
    await async_client.post(
        "/api/v1/cases",
        json={"title": "User A Case", "description": "Desc A"},
        headers={"Authorization": f"Bearer {token_a}"},
    )

    # User B creates case
    await async_client.post(
        "/api/v1/cases",
        json={"title": "User B Case", "description": "Desc B"},
        headers={"Authorization": f"Bearer {token_b}"},
    )

    # User A lists cases -> must only see User A Case
    list_a = await async_client.get("/api/v1/cases", headers={"Authorization": f"Bearer {token_a}"})
    assert list_a.status_code == 200
    items_a = list_a.json()["items"]
    assert len(items_a) == 1
    assert items_a[0]["title"] == "User A Case"

    # User B lists cases -> must only see User B Case
    list_b = await async_client.get("/api/v1/cases", headers={"Authorization": f"Bearer {token_b}"})
    assert list_b.status_code == 200
    items_b = list_b.json()["items"]
    assert len(items_b) == 1
    assert items_b[0]["title"] == "User B Case"


@pytest.mark.asyncio
async def test_get_case_access_control(async_client: AsyncClient, test_db):
    """Verify unauthorized requester cannot view another requester's case."""
    user_a = User(email="owner@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    user_b = User(email="snooper@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    test_db.add_all([user_a, user_b])
    await test_db.commit()

    token_a = make_token(user_a)
    token_b = make_token(user_b)

    create_res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Confidential Issue", "description": "Private details"},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    case_id = create_res.json()["id"]

    # Snooper attempts to read
    snoop_res = await async_client.get(f"/api/v1/cases/{case_id}", headers={"Authorization": f"Bearer {token_b}"})
    assert snoop_res.status_code == 403
    assert snoop_res.json()["error"]["code"] == "PERMISSION_DENIED"


@pytest.mark.asyncio
async def test_optimistic_locking_collision(async_client: AsyncClient, test_db):
    """Verify concurrent update conflict returns 409 STALE_VERSION per SRS §7.12."""
    user = User(email="staff@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    create_res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Original Title", "description": "Desc"},
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = create_res.json()["id"]
    assert create_res.json()["version"] == 1

    # First update with version 1 -> succeeds, version becomes 2
    update_1 = await async_client.patch(
        f"/api/v1/cases/{case_id}",
        json={"title": "Updated Title 1", "version": 1},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert update_1.status_code == 200
    assert update_1.json()["version"] == 2

    # Second update with stale version 1 -> 409 Conflict
    update_conflict = await async_client.patch(
        f"/api/v1/cases/{case_id}",
        json={"title": "Conflicting Update", "version": 1},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert update_conflict.status_code == 409
    assert update_conflict.json()["error"]["code"] == "STALE_VERSION"


@pytest.mark.asyncio
async def test_case_state_transitions(async_client: AsyncClient, test_db):
    """Verify valid state transitions per SRS §6.1 state diagram."""
    operator = User(email="op@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add(operator)
    await test_db.commit()
    token = make_token(operator)

    # 1. Created as NEW
    create_res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Lifecycle Test", "description": "Testing full path"},
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = create_res.json()["id"]
    v = create_res.json()["version"]

    # 2. NEW -> IN_ASSESSMENT
    t1 = await async_client.post(
        f"/api/v1/cases/{case_id}/transition",
        json={"new_status": "in_assessment", "version": v},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert t1.status_code == 200
    assert t1.json()["status"] == "in_assessment"
    v = t1.json()["version"]

    # 3. IN_ASSESSMENT -> ASSIGNED
    t2 = await async_client.post(
        f"/api/v1/cases/{case_id}/transition",
        json={"new_status": "assigned", "version": v},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert t2.status_code == 200
    assert t2.json()["status"] == "assigned"
    v = t2.json()["version"]

    # 4. ASSIGNED -> RESOLVED
    t3 = await async_client.post(
        f"/api/v1/cases/{case_id}/transition",
        json={"new_status": "resolved", "version": v},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert t3.status_code == 200
    assert t3.json()["status"] == "resolved"
    assert t3.json()["resolved_at"] is not None
    v = t3.json()["version"]

    # 5. RESOLVED -> CLOSED
    t4 = await async_client.post(
        f"/api/v1/cases/{case_id}/transition",
        json={"new_status": "closed", "version": v},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert t4.status_code == 200
    assert t4.json()["status"] == "closed"
    assert t4.json()["closed_at"] is not None
    v = t4.json()["version"]

    # 6. CLOSED -> ASSIGNED (Reopen within 7 days)
    t5 = await async_client.post(
        f"/api/v1/cases/{case_id}/transition",
        json={"new_status": "assigned", "reason": "Issue recurred", "version": v},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert t5.status_code == 200
    assert t5.json()["status"] == "assigned"
    assert t5.json()["resolved_at"] is None
    assert t5.json()["closed_at"] is None


@pytest.mark.asyncio
async def test_invalid_state_transition_rejected(async_client: AsyncClient, test_db):
    """Verify jumping from NEW directly to CLOSED is rejected with 400."""
    user = User(email="op2@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Invalid Transition", "description": "Desc"},
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = res.json()["id"]

    jump_res = await async_client.post(
        f"/api/v1/cases/{case_id}/transition",
        json={"new_status": "closed", "version": 1},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert jump_res.status_code == 400
    assert jump_res.json()["error"]["code"] == "INVALID_STATE_TRANSITION"


@pytest.mark.asyncio
async def test_reopen_window_expired(async_client: AsyncClient, test_db):
    """Verify reopening closed case beyond 7 days is rejected per SRS §6.1."""
    user = User(email="op3@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    # Direct DB setup of an old closed case
    case = Case(
        reference_number="INC-2026-999999",
        title="Old Closed Case",
        description="Desc",
        status=CaseStatus.CLOSED,
        requester_id=user.id,
        closed_at=datetime.now(timezone.utc) - timedelta(days=8),
        version=1,
    )
    test_db.add(case)
    await test_db.commit()
    await test_db.refresh(case)

    reopen_res = await async_client.post(
        f"/api/v1/cases/{case.id}/transition",
        json={"new_status": "assigned", "version": 1},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert reopen_res.status_code == 400
    assert reopen_res.json()["error"]["code"] == "REOPEN_WINDOW_EXPIRED"


@pytest.mark.asyncio
async def test_message_visibility_filtering(async_client: AsyncClient, test_db):
    """Verify requester cannot read or create internal_only notes per SRS §4 & §7.6."""
    requester = User(email="req_msg@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    operator = User(email="op_msg@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add_all([requester, operator])
    await test_db.commit()

    req_token = make_token(requester)
    op_token = make_token(operator)

    # Requester creates case
    case_res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Message Visibility Test", "description": "Desc"},
        headers={"Authorization": f"Bearer {req_token}"},
    )
    case_id = case_res.json()["id"]

    # 1. Operator posts internal_only note
    internal_res = await async_client.post(
        f"/api/v1/cases/{case_id}/messages",
        json={"body": "Customer seems confused, investigate tier 2.", "visibility": "internal_only"},
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert internal_res.status_code == 201

    # 2. Operator posts requester_visible message
    public_res = await async_client.post(
        f"/api/v1/cases/{case_id}/messages",
        json={"body": "We are currently reviewing your network logs.", "visibility": "requester_visible"},
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert public_res.status_code == 201

    # 3. Requester fetches messages -> must ONLY see requester_visible message!
    req_messages_res = await async_client.get(
        f"/api/v1/cases/{case_id}/messages",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert req_messages_res.status_code == 200
    req_msgs = req_messages_res.json()
    assert len(req_msgs) == 1
    assert req_msgs[0]["visibility"] == "requester_visible"
    assert "confused" not in req_msgs[0]["body"]

    # 4. Operator fetches messages -> sees both
    op_messages_res = await async_client.get(
        f"/api/v1/cases/{case_id}/messages",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert op_messages_res.status_code == 200
    assert len(op_messages_res.json()) == 2

    # 5. Requester attempts to create internal_only message -> 403
    req_internal_res = await async_client.post(
        f"/api/v1/cases/{case_id}/messages",
        json={"body": "Sneaking an internal note", "visibility": "internal_only"},
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert req_internal_res.status_code == 403
    assert req_internal_res.json()["error"]["code"] == "PERMISSION_DENIED"


@pytest.mark.asyncio
async def test_case_soft_delete(async_client: AsyncClient, test_db):
    """Verify soft delete marks deleted_at and hides case from normal queries."""
    user = User(email="del_user@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Delete Me", "description": "Desc"},
        headers={"Authorization": f"Bearer {token}"},
    )
    case_id = res.json()["id"]

    # Delete
    del_res = await async_client.delete(f"/api/v1/cases/{case_id}", headers={"Authorization": f"Bearer {token}"})
    assert del_res.status_code == 204

    # Subsequent GET returns 404
    get_res = await async_client.get(f"/api/v1/cases/{case_id}", headers={"Authorization": f"Bearer {token}"})
    assert get_res.status_code == 404
    assert get_res.json()["error"]["code"] == "CASE_NOT_FOUND"


@pytest.mark.asyncio
async def test_case_relationships(async_client: AsyncClient, test_db):
    """Verify case relationship linking and self-link rejection."""
    user = User(email="op_rel@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    c1 = await async_client.post("/api/v1/cases", json={"title": "Case 1", "description": "D1"}, headers={"Authorization": f"Bearer {token}"})
    c2 = await async_client.post("/api/v1/cases", json={"title": "Case 2", "description": "D2"}, headers={"Authorization": f"Bearer {token}"})
    id1 = c1.json()["id"]
    id2 = c2.json()["id"]

    # Link C2 as duplicate of C1
    rel_res = await async_client.post(
        f"/api/v1/cases/{id1}/relationships",
        json={"related_case_id": id2, "relationship_type": "duplicate_of"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert rel_res.status_code == 201
    assert rel_res.json()["relationship_type"] == "duplicate_of"

    # Self link rejected
    self_res = await async_client.post(
        f"/api/v1/cases/{id1}/relationships",
        json={"related_case_id": id1, "relationship_type": "related_to"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert self_res.status_code == 400
    assert self_res.json()["error"]["code"] == "INVALID_RELATIONSHIP"


@pytest.mark.asyncio
async def test_audit_logs_recorded(async_client: AsyncClient, test_db):
    """Verify append-only audit logs are created and accessible only to staff."""
    requester = User(email="audit_req@example.com", password_hash="h", role=UserRole.REQUESTER, email_verified=True)
    operator = User(email="audit_op@example.com", password_hash="h", role=UserRole.OPERATOR, email_verified=True)
    test_db.add_all([requester, operator])
    await test_db.commit()

    req_token = make_token(requester)
    op_token = make_token(operator)

    # Requester creates case
    case_res = await async_client.post(
        "/api/v1/cases",
        json={"title": "Audit Test", "description": "Testing log trail"},
        headers={"Authorization": f"Bearer {req_token}"},
    )
    case_id = case_res.json()["id"]

    # Requester cannot read audit logs
    unauth_audit = await async_client.get(
        f"/api/v1/cases/{case_id}/audit-logs",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert unauth_audit.status_code == 403
    assert unauth_audit.json()["error"]["code"] == "PERMISSION_DENIED"

    # Operator reads audit logs
    auth_audit = await async_client.get(
        f"/api/v1/cases/{case_id}/audit-logs",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert auth_audit.status_code == 200
    logs = auth_audit.json()
    assert len(logs) >= 1
    assert logs[0]["action"] == "CASE_CREATED"
