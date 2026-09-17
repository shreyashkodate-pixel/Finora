import json
import uuid
import pytest
from starlette.testclient import TestClient

from core.security import create_access_token
from integrations.webhooks import WebhookDispatcher
from main import app
from models.case import Case
from models.enums import CasePriority, CaseStatus, CaseType, UserRole
from models.user import User
from realtime.connection_manager import ConnectionManager


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_connection_manager_room_broadcast():
    manager = ConnectionManager()

    class MockWebSocket:
        def __init__(self):
            self.accepted = False
            self.sent_messages = []

        async def accept(self):
            self.accepted = True

        async def send_text(self, text: str):
            self.sent_messages.append(text)

    ws1 = MockWebSocket()
    ws2 = MockWebSocket()
    case_id = "test-case-123"

    await manager.connect(case_id, ws1)
    await manager.connect(case_id, ws2)
    assert ws1.accepted and ws2.accepted

    await manager.broadcast_to_case(case_id, "TEST_EVENT", {"msg": "hello room"})
    assert len(ws1.sent_messages) == 1
    assert len(ws2.sent_messages) == 1
    parsed = json.loads(ws1.sent_messages[0])
    assert parsed["event"] == "TEST_EVENT"
    assert parsed["data"]["msg"] == "hello room"

    manager.disconnect(case_id, ws1)
    manager.disconnect(case_id, ws2)
    assert case_id not in manager._case_rooms


@pytest.mark.asyncio
async def test_websocket_endpoint_flow(test_db):
    operator = User(
        email="operator_ws@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_ws@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-6601",
        title="Active Directory Kerberos Ticket Failure",
        description="Users cannot login to domain controllers.",
        type=CaseType.INCIDENT,
        status=CaseStatus.ASSIGNED,
        priority=CasePriority.P1,
        requester_id=requester.id,
        site="HQ",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)

    async def override_get_db():
        yield test_db

    from db.session import get_db_session
    app.dependency_overrides[get_db_session] = override_get_db

    try:
        client = TestClient(app)
        with client.websocket_connect(f"/api/v1/ws/cases/{case.id}?token={op_token}") as websocket:
            # Send ping
            websocket.send_text(json.dumps({"action": "ping"}))
            response = websocket.receive_text()
            assert json.loads(response)["event"] == "pong"

            # Send typing indicator
            websocket.send_text(json.dumps({"action": "typing", "is_typing": True}))
            broadcast = websocket.receive_text()
            parsed_broadcast = json.loads(broadcast)
            assert parsed_broadcast["event"] == "TYPING_INDICATOR"
            assert parsed_broadcast["data"]["is_typing"] is True
    finally:
        app.dependency_overrides.clear()



@pytest.mark.asyncio
async def test_webhook_dispatcher_formatting():
    # Test Slack formatting
    slack_res = await WebhookDispatcher.dispatch_slack_alert(
        webhook_url=None,
        title="Critical Outage on Core Switch",
        message="BGP session lost on peer 198.51.100.1",
        priority="P1",
        fields={"Host": "switch-01.dc1", "Impact": "12 Racks Unreachable"},
    )
    assert slack_res is True

    # Test Teams formatting
    teams_res = await WebhookDispatcher.dispatch_teams_alert(
        webhook_url=None,
        title="Major Incident MAJ-2026-0001 Declared",
        message="Incident Commander initialized war room bridge.",
        priority="P1",
        fields={"Commander": "Commander Operator", "Bridge": "https://meet.google.com/test"},
    )
    assert teams_res is True
