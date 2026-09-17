import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from models.case import Case
from models.user import User
from models.notification import Notification
from models.enums import UserRole, CaseStatus, CaseType, CasePriority, MessageVisibility
from core.security import create_access_token
from providers.notifications import set_notification_provider
from providers.notifications.mock import MockNotificationProvider


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.fixture(autouse=True)
def setup_mock_notification_provider():
    """Ensure tests run against a fresh MockNotificationProvider."""
    provider = MockNotificationProvider()
    set_notification_provider(provider)
    yield provider
    set_notification_provider(None)


@pytest.mark.asyncio
async def test_case_created_dispatches_notification_and_email(
    async_client: AsyncClient, test_db, setup_mock_notification_provider: MockNotificationProvider
):
    """Verify case creation sends intake confirmation email and persists in-app notification."""
    user = User(
        email="req_notif@example.com",
        password_hash="dummy_hash",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    payload = {
        "title": "Email server connectivity failure",
        "description": "Cannot connect to inbound mail.",
        "type": "incident",
        "priority": "p2",
    }
    response = await async_client.post(
        "/api/v1/cases",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 201
    case_data = response.json()
    ref_num = case_data["reference_number"]

    # 1. Verify outbound email captured by provider
    emails = setup_mock_notification_provider.sent_emails
    assert len(emails) == 1
    assert emails[0]["to_email"] == "req_notif@example.com"
    assert ref_num in emails[0]["subject"]
    assert "received" in emails[0]["body_text"].lower()

    # 2. Verify in-app notification persisted
    stmt = select(Notification).where(Notification.user_id == user.id)
    res = await test_db.execute(stmt)
    notifications = res.scalars().all()
    assert len(notifications) == 1
    assert notifications[0].event_type.value == "case_created"
    assert notifications[0].is_read is False
    assert ref_num in notifications[0].title


@pytest.mark.asyncio
async def test_case_assigned_dispatches_notification(
    async_client: AsyncClient, test_db, setup_mock_notification_provider: MockNotificationProvider
):
    """Verify case assignment alerts assignee via in-app notification and email."""
    requester = User(email="req_assign@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    operator = User(email="operator_assignee@example.com", password_hash="dummy_hash", role=UserRole.OPERATOR, email_verified=True)
    test_db.add_all([requester, operator])
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000201",
        type=CaseType.INCIDENT,
        title="Network switch packet drops",
        description="Core switch 2 dropping packets.",
        status=CaseStatus.NEW,
        priority=CasePriority.P2,
        requester_id=requester.id,
        version=1,
    )
    test_db.add(case)
    await test_db.commit()

    setup_mock_notification_provider.clear()
    token_op = make_token(operator)

    # Assign case to operator
    update_payload = {
        "owner_id": str(operator.id),
        "version": 1,
    }
    patch_res = await async_client.patch(
        f"/api/v1/cases/{case.id}",
        json=update_payload,
        headers={"Authorization": f"Bearer {token_op}"},
    )
    assert patch_res.status_code == 200

    # 1. Verify email dispatched to assignee
    emails = setup_mock_notification_provider.sent_emails
    assert len(emails) == 1
    assert emails[0]["to_email"] == "operator_assignee@example.com"
    assert "Case Assigned" in emails[0]["subject"]

    # 2. Verify in-app notification for operator
    stmt = select(Notification).where(Notification.user_id == operator.id)
    res = await test_db.execute(stmt)
    notifs = res.scalars().all()
    assert len(notifs) == 1
    assert notifs[0].event_type.value == "case_assigned"
    assert notifs[0].is_read is False


@pytest.mark.asyncio
async def test_message_visibility_and_notification_masking(
    async_client: AsyncClient, test_db, setup_mock_notification_provider: MockNotificationProvider
):
    """Verify visible notes notify requester, while internal_only notes NEVER notify requester."""
    requester = User(email="req_msg@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    operator = User(email="op_msg@example.com", password_hash="dummy_hash", role=UserRole.OPERATOR, email_verified=True)
    test_db.add_all([requester, operator])
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000202",
        type=CaseType.INCIDENT,
        title="Printer driver fault",
        description="Printer won't accept print jobs.",
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P3,
        requester_id=requester.id,
        owner_id=operator.id,
        version=1,
    )
    test_db.add(case)
    await test_db.commit()

    token_op = make_token(operator)
    setup_mock_notification_provider.clear()

    # 1. Post internal_only note -> Requester must NOT receive notification or email
    internal_res = await async_client.post(
        f"/api/v1/cases/{case.id}/messages",
        json={"body": "Internal note: vendor bug confirmed.", "visibility": "internal_only"},
        headers={"Authorization": f"Bearer {token_op}"},
    )
    assert internal_res.status_code == 201
    assert len(setup_mock_notification_provider.sent_emails) == 0

    req_notifs = (await test_db.execute(select(Notification).where(Notification.user_id == requester.id))).scalars().all()
    assert len(req_notifs) == 0

    # 2. Post requester_visible note -> Requester MUST receive notification and email
    visible_res = await async_client.post(
        f"/api/v1/cases/{case.id}/messages",
        json={"body": "We applied a hotfix. Please test again.", "visibility": "requester_visible"},
        headers={"Authorization": f"Bearer {token_op}"},
    )
    assert visible_res.status_code == 201
    assert len(setup_mock_notification_provider.sent_emails) == 1
    assert setup_mock_notification_provider.sent_emails[0]["to_email"] == "req_msg@example.com"

    req_notifs_after = (await test_db.execute(select(Notification).where(Notification.user_id == requester.id))).scalars().all()
    assert len(req_notifs_after) == 1
    assert req_notifs_after[0].event_type.value == "new_message"


@pytest.mark.asyncio
async def test_case_resolution_and_reopen_notifications(
    async_client: AsyncClient, test_db, setup_mock_notification_provider: MockNotificationProvider
):
    """Verify resolving notifies requester, and reopening notifies case owner."""
    requester = User(email="req_lifecycle@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    operator = User(email="op_lifecycle@example.com", password_hash="dummy_hash", role=UserRole.OPERATOR, email_verified=True)
    test_db.add_all([requester, operator])
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000203",
        type=CaseType.INCIDENT,
        title="Laptop keyboard replacement",
        description="Sticking keys.",
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P3,
        requester_id=requester.id,
        owner_id=operator.id,
        version=1,
    )
    test_db.add(case)
    await test_db.commit()

    token_op = make_token(operator)
    token_req = make_token(requester)
    setup_mock_notification_provider.clear()

    # 1. Resolve case -> Requester receives notification
    resolve_res = await async_client.post(
        f"/api/v1/cases/{case.id}/transition",
        json={"new_status": "resolved", "reason": "Hardware replaced", "version": 1},
        headers={"Authorization": f"Bearer {token_op}"},
    )
    assert resolve_res.status_code == 200

    emails = setup_mock_notification_provider.sent_emails
    assert len(emails) == 1
    assert emails[0]["to_email"] == "req_lifecycle@example.com"
    assert "Resolved" in emails[0]["subject"]
    assert "7 calendar days" in emails[0]["body_text"]

    # 2. Reopen case by Requester -> Operator receives notification
    setup_mock_notification_provider.clear()
    reopen_res = await async_client.post(
        f"/api/v1/cases/{case.id}/transition",
        json={"new_status": "assigned", "reason": "Spacebar still sticky", "version": 2},
        headers={"Authorization": f"Bearer {token_req}"},
    )
    assert reopen_res.status_code == 200

    emails2 = setup_mock_notification_provider.sent_emails
    assert len(emails2) == 1
    assert emails2[0]["to_email"] == "op_lifecycle@example.com"
    assert "Reopened" in emails2[0]["subject"]


@pytest.mark.asyncio
async def test_in_app_notification_management_endpoints(
    async_client: AsyncClient, test_db
):
    """Verify listing notifications, unread counts, mark-as-read, and mark-all-read endpoints."""
    user = User(email="user_inapp@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    token = make_token(user)

    # Seed 3 in-app notifications
    notif1 = Notification(user_id=user.id, title="Alert 1", message="Message 1", event_type="case_created", is_read=False)
    notif2 = Notification(user_id=user.id, title="Alert 2", message="Message 2", event_type="new_message", is_read=False)
    notif3 = Notification(user_id=user.id, title="Alert 3", message="Message 3", event_type="case_resolved", is_read=False)
    test_db.add_all([notif1, notif2, notif3])
    await test_db.commit()

    # 1. Check unread count -> 3
    count_res = await async_client.get(
        "/api/v1/notifications/unread-count",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert count_res.status_code == 200
    assert count_res.json()["unread_count"] == 3

    # 2. List notifications -> 3 items
    list_res = await async_client.get(
        "/api/v1/notifications",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert list_res.status_code == 200
    list_data = list_res.json()
    assert list_data["total"] == 3
    assert list_data["unread_count"] == 3
    assert len(list_data["items"]) == 3

    # 3. Mark single notification as read
    patch_res = await async_client.patch(
        f"/api/v1/notifications/{notif1.id}/read",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["is_read"] is True

    # Check unread count -> 2
    count_res2 = await async_client.get(
        "/api/v1/notifications/unread-count",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert count_res2.json()["unread_count"] == 2

    # 4. Mark all as read
    mark_all_res = await async_client.post(
        "/api/v1/notifications/mark-all-read",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert mark_all_res.status_code == 200
    assert mark_all_res.json()["marked_count"] == 2
    assert mark_all_res.json()["unread_count"] == 0

    # Verify unread count is now 0
    count_res3 = await async_client.get(
        "/api/v1/notifications/unread-count",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert count_res3.json()["unread_count"] == 0


@pytest.mark.asyncio
async def test_email_delivery_failure_resilience(
    async_client: AsyncClient, test_db, setup_mock_notification_provider: MockNotificationProvider
):
    """Verify email delivery failure does NOT fail or rollback case creation per SRS §7.7 & §7.14."""
    user = User(email="req_resilient@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.commit()
    token = make_token(user)

    # Configure provider to simulate outbound email failure
    setup_mock_notification_provider.simulate_failure = True

    payload = {
        "title": "Email server offline test",
        "description": "Testing that case creation succeeds even if email provider is down.",
        "type": "incident",
        "priority": "p3",
    }
    response = await async_client.post(
        "/api/v1/cases",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    # The HTTP request must succeed 201 Created despite email dispatch failure
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == payload["title"]

    # In-app notification must still be persisted
    stmt = select(Notification).where(Notification.user_id == user.id)
    notifs = (await test_db.execute(stmt)).scalars().all()
    assert len(notifs) == 1
