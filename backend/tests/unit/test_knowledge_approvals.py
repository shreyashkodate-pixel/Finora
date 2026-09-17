import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from core.security import create_access_token
from models.audit import AuditLog
from models.case import Case
from models.enums import (
    ApprovalDecision,
    CasePriority,
    CaseStatus,
    CaseType,
    KnowledgeState,
    UserRole,
)
from models.knowledge import KnowledgeArticle, Approval
from models.message import Message
from models.user import User


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_author_knowledge_article_success(async_client: AsyncClient, test_db):
    """Staff can create a knowledge article, generating an audit log."""
    operator = User(
        email="op_kb@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()

    token = make_token(operator)
    payload = {
        "title": "Configuring Corporate Wi-Fi on Linux",
        "body": "# Wi-Fi Setup\nUse WPA2-Enterprise with PEAP/MSCHAPv2 credentials.",
        "state": "draft",
    }
    resp = await async_client.post(
        "/api/v1/knowledge",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == payload["title"]
    assert data["state"] == "draft"
    assert data["owner_id"] == str(operator.id)

    # Check audit log
    audit_stmt = select(AuditLog).where(
        AuditLog.action == "KNOWLEDGE_ARTICLE_CREATED",
        AuditLog.target_id == uuid.UUID(data["id"]),
    )
    audit_res = await test_db.execute(audit_stmt)
    audit = audit_res.scalar_one_or_none()
    assert audit is not None
    assert audit.actor_id == operator.id


@pytest.mark.asyncio
async def test_requester_cannot_author_knowledge_article(async_client: AsyncClient, test_db):
    """Requesters cannot author articles (SRS §7.6: only authorized staff)."""
    requester = User(
        email="req_kb@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(requester)
    await test_db.commit()

    token = make_token(requester)
    payload = {
        "title": "Unauthorized Article Attempt",
        "body": "Requesters should not be permitted to author articles.",
    }
    resp = await async_client.post(
        "/api/v1/knowledge",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_requester_visibility_restricted_to_published(async_client: AsyncClient, test_db):
    """Requesters can only view published articles, not drafts."""
    operator = User(
        email="op_vis@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_vis@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    draft_art = KnowledgeArticle(
        title="Internal Troubleshooting Draft",
        body="Internal secret debug steps.",
        owner_id=operator.id,
        state=KnowledgeState.DRAFT,
        created_at=now,
        updated_at=now,
    )
    pub_art = KnowledgeArticle(
        title="Public Self-Service Password Reset",
        body="Navigate to portal and click forgot password.",
        owner_id=operator.id,
        state=KnowledgeState.PUBLISHED,
        created_at=now,
        updated_at=now,
    )
    test_db.add_all([draft_art, pub_art])
    await test_db.commit()

    req_token = make_token(requester)

    # Requester listing: only published returned
    list_resp = await async_client.get(
        "/api/v1/knowledge",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert list_resp.status_code == 200
    list_data = list_resp.json()
    titles = [item["title"] for item in list_data["items"]]
    assert "Public Self-Service Password Reset" in titles
    assert "Internal Troubleshooting Draft" not in titles

    # Requester direct get on draft -> 403 Forbidden
    draft_resp = await async_client.get(
        f"/api/v1/knowledge/{draft_art.id}",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert draft_resp.status_code == 403

    # Requester direct get on published -> 200 OK
    pub_resp = await async_client.get(
        f"/api/v1/knowledge/{pub_art.id}",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert pub_resp.status_code == 200


@pytest.mark.asyncio
async def test_search_knowledge_articles(async_client: AsyncClient, test_db):
    """Search queries match keywords across title and body."""
    operator = User(
        email="op_search@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()

    now = datetime.now(timezone.utc)
    art1 = KnowledgeArticle(
        title="VPN Client Troubleshooting",
        body="Steps to reconnect AnyConnect tunnel.",
        owner_id=operator.id,
        state=KnowledgeState.PUBLISHED,
        created_at=now,
        updated_at=now,
    )
    art2 = KnowledgeArticle(
        title="Printer Setup Guide",
        body="Add network printer by IP address.",
        owner_id=operator.id,
        state=KnowledgeState.PUBLISHED,
        created_at=now,
        updated_at=now,
    )
    test_db.add_all([art1, art2])
    await test_db.commit()

    token = make_token(operator)
    resp = await async_client.get(
        "/api/v1/knowledge?search=AnyConnect",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["title"] == "VPN Client Troubleshooting"


@pytest.mark.asyncio
async def test_update_and_archive_knowledge_article(async_client: AsyncClient, test_db):
    """Article author can update content, and Manager can archive."""
    operator = User(
        email="op_author@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    other_operator = User(
        email="op_other@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    manager = User(
        email="mgr_kb@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, other_operator, manager])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    article = KnowledgeArticle(
        title="Legacy Email Migration",
        body="Original migration instructions.",
        owner_id=operator.id,
        state=KnowledgeState.DRAFT,
        created_at=now,
        updated_at=now,
    )
    test_db.add(article)
    await test_db.commit()

    # Unauthorized operator attempt to update -> 403
    other_token = make_token(other_operator)
    bad_upd = await async_client.put(
        f"/api/v1/knowledge/{article.id}",
        json={"title": "Unauthorized Change"},
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert bad_upd.status_code == 403

    # Author updates article
    author_token = make_token(operator)
    good_upd = await async_client.put(
        f"/api/v1/knowledge/{article.id}",
        json={"title": "Updated Email Migration Guide", "state": "published"},
        headers={"Authorization": f"Bearer {author_token}"},
    )
    assert good_upd.status_code == 200
    assert good_upd.json()["title"] == "Updated Email Migration Guide"
    assert good_upd.json()["state"] == "published"

    # Manager archives article
    mgr_token = make_token(manager)
    arch_resp = await async_client.post(
        f"/api/v1/knowledge/{article.id}/archive",
        headers={"Authorization": f"Bearer {mgr_token}"},
    )
    assert arch_resp.status_code == 200
    assert arch_resp.json()["state"] == "archived"


@pytest.mark.asyncio
async def test_suggest_articles_for_case(async_client: AsyncClient, test_db):
    """Contextual suggestions match tokens from case title and description."""
    operator = User(
        email="op_sugg@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()

    now = datetime.now(timezone.utc)
    vpn_art = KnowledgeArticle(
        title="Resolving VPN Gateway Disconnections",
        body="Flush DNS and re-import AnyConnect security profile.",
        owner_id=operator.id,
        state=KnowledgeState.PUBLISHED,
        created_at=now,
        updated_at=now,
    )
    printer_art = KnowledgeArticle(
        title="Paper Jam Clearing Instructions",
        body="Open tray 2 and remove jammed paper.",
        owner_id=operator.id,
        state=KnowledgeState.PUBLISHED,
        created_at=now,
        updated_at=now,
    )
    test_db.add_all([vpn_art, printer_art])

    case = Case(
        reference_number="INC-2026-000099",
        title="VPN gateway fails every 10 minutes",
        description="AnyConnect disconnects frequently.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        requester_id=operator.id,
        site="Campus North",
        created_at=now,
    )
    test_db.add(case)
    await test_db.commit()

    token = make_token(operator)
    resp = await async_client.get(
        f"/api/v1/knowledge/suggestions/case/{case.id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    suggested = resp.json()
    assert len(suggested) >= 1
    assert suggested[0]["title"] == "Resolving VPN Gateway Disconnections"


@pytest.mark.asyncio
async def test_request_approval_workflow_and_state_transition(async_client: AsyncClient, test_db):
    """Requesting approval transitions case to AWAITING_APPROVAL, increments version, and adds timeline message."""
    operator = User(
        email="op_appr@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    manager = User(
        email="mgr_appr@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, manager])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    # Case in ASSIGNED status
    case = Case(
        reference_number="REQ-2026-000045",
        title="Request Production Database Access",
        description="Need read-write access to replica DB.",
        type=CaseType.SERVICE_REQUEST,
        priority=CasePriority.P3,
        status=CaseStatus.ASSIGNED,
        requester_id=operator.id,
        owner_id=operator.id,
        site="Campus North",
        version=1,
        created_at=now,
    )
    test_db.add(case)
    await test_db.commit()

    token = make_token(operator)
    payload = {
        "approver_id": str(manager.id),
        "reason": "Production database access requires managerial authorization per policy.",
    }
    resp = await async_client.post(
        f"/api/v1/cases/{case.id}/approvals",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    appr_data = resp.json()
    assert appr_data["decision"] == "pending"
    assert appr_data["case_id"] == str(case.id)
    assert appr_data["approver_id"] == str(manager.id)

    # Verify case transitioned to awaiting_approval and version incremented
    await test_db.refresh(case)
    assert case.status == CaseStatus.AWAITING_APPROVAL
    assert case.version == 2

    # Verify timeline message created
    msg_stmt = select(Message).where(Message.case_id == case.id)
    msg_res = await test_db.execute(msg_stmt)
    msg = msg_res.scalar_one_or_none()
    assert msg is not None
    assert f"Approval requested from {manager.email}" in msg.body

    # Verify audit log
    audit_stmt = select(AuditLog).where(
        AuditLog.action == "APPROVAL_REQUESTED",
        AuditLog.target_id == case.id,
    )
    audit_res = await test_db.execute(audit_stmt)
    audit = audit_res.scalar_one_or_none()
    assert audit is not None


@pytest.mark.asyncio
async def test_approval_request_validation_errors(async_client: AsyncClient, test_db):
    """Validation: non-ASSIGNED case fails; non-manager approver fails; duplicate approval fails."""
    operator = User(
        email="op_val@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester_approver = User(
        email="req_fake_appr@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    manager = User(
        email="mgr_val@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester_approver, manager])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    # Case in NEW status (not ASSIGNED)
    case_new = Case(
        reference_number="INC-2026-000078",
        title="Unassigned Incident",
        description="Fresh ticket.",
        type=CaseType.INCIDENT,
        priority=CasePriority.P3,
        status=CaseStatus.NEW,
        requester_id=operator.id,
        site="Campus North",
        version=1,
        created_at=now,
    )
    test_db.add(case_new)
    await test_db.commit()

    token = make_token(operator)

    # 1. Non-ASSIGNED case rejects approval request -> 400
    resp1 = await async_client.post(
        f"/api/v1/cases/{case_new.id}/approvals",
        json={"approver_id": str(manager.id)},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp1.status_code == 400
    assert resp1.json()["error"]["code"] == "INVALID_CASE_STATUS"

    # Move case to ASSIGNED
    case_new.status = CaseStatus.ASSIGNED
    await test_db.commit()

    # 2. Approver with Requester role rejects -> 400
    resp2 = await async_client.post(
        f"/api/v1/cases/{case_new.id}/approvals",
        json={"approver_id": str(requester_approver.id)},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp2.status_code == 400
    assert resp2.json()["error"]["code"] == "INVALID_APPROVER_ROLE"

    # 3. Successful first request
    resp3 = await async_client.post(
        f"/api/v1/cases/{case_new.id}/approvals",
        json={"approver_id": str(manager.id)},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp3.status_code == 201

    # 4. Duplicate pending request rejects -> 409 Conflict
    resp4 = await async_client.post(
        f"/api/v1/cases/{case_new.id}/approvals",
        json={"approver_id": str(manager.id)},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp4.status_code == 409
    assert resp4.json()["error"]["code"] == "APPROVAL_ALREADY_PENDING"


@pytest.mark.asyncio
async def test_approval_decision_approved_restores_assigned_status(async_client: AsyncClient, test_db):
    """Approving an approval transitions case back to ASSIGNED, creates message and audit log."""
    operator = User(
        email="op_decide@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    lead = User(
        email="lead_decide@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, lead])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    case = Case(
        reference_number="REQ-2026-000088",
        title="Admin Privilege Elevation",
        description="Temporary domain admin rights.",
        type=CaseType.SERVICE_REQUEST,
        priority=CasePriority.P2,
        status=CaseStatus.AWAITING_APPROVAL,
        requester_id=operator.id,
        owner_id=operator.id,
        site="Campus North",
        version=2,
        created_at=now,
    )
    test_db.add(case)
    await test_db.flush()

    approval_id = uuid.uuid4()
    approval = Approval(
        id=approval_id,
        case_id=case.id,
        approver_id=lead.id,
        decision=ApprovalDecision.PENDING,
        reason="Security policy check required",
        created_at=now,
    )
    test_db.add(approval)
    await test_db.commit()

    lead_token = make_token(lead)
    decision_payload = {
        "decision": "approved",
        "reason": "Security review completed and verified in ticketing.",
    }
    resp = await async_client.post(
        f"/api/v1/approvals/{approval.id}/decision",
        json=decision_payload,
        headers={"Authorization": f"Bearer {lead_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["decision"] == "approved"
    assert data["decided_at"] is not None

    # Verify case status returned to ASSIGNED per state machine
    await test_db.refresh(case)
    assert case.status == CaseStatus.ASSIGNED
    assert case.version == 3

    # Verify audit log
    audit_stmt = select(AuditLog).where(
        AuditLog.action == "APPROVAL_DECIDED",
        AuditLog.target_id == approval.id,
    )
    audit_res = await test_db.execute(audit_stmt)
    audit = audit_res.scalar_one_or_none()
    assert audit is not None


@pytest.mark.asyncio
async def test_approval_decision_rejected_and_unauthorized_guard(async_client: AsyncClient, test_db):
    """Unauthorized user cannot decide; rejection transitions case to ASSIGNED with rejection note."""
    operator = User(
        email="op_rej@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    unrelated_operator = User(
        email="op_unrelated@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    lead = User(
        email="lead_rej@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, unrelated_operator, lead])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    case = Case(
        reference_number="REQ-2026-000092",
        title="External USB Drive Exemption",
        description="Request to use unauthorized external storage.",
        type=CaseType.SERVICE_REQUEST,
        priority=CasePriority.P3,
        status=CaseStatus.AWAITING_APPROVAL,
        requester_id=operator.id,
        site="Campus North",
        version=2,
        created_at=now,
    )
    test_db.add(case)
    await test_db.flush()

    approval_id = uuid.uuid4()
    approval = Approval(
        id=approval_id,
        case_id=case.id,
        approver_id=lead.id,
        decision=ApprovalDecision.PENDING,
        reason="DLP compliance review",
        created_at=now,
    )
    test_db.add(approval)
    await test_db.commit()

    # 1. Unauthorized operator attempts decision -> 403
    unauth_token = make_token(unrelated_operator)
    bad_resp = await async_client.post(
        f"/api/v1/approvals/{approval.id}/decision",
        json={"decision": "approved"},
        headers={"Authorization": f"Bearer {unauth_token}"},
    )
    assert bad_resp.status_code == 403

    # 2. Designated lead submits rejection
    lead_token = make_token(lead)
    rej_resp = await async_client.post(
        f"/api/v1/approvals/{approval.id}/decision",
        json={"decision": "rejected", "reason": "Violates corporate DLP endpoint policies."},
        headers={"Authorization": f"Bearer {lead_token}"},
    )
    assert rej_resp.status_code == 200
    assert rej_resp.json()["decision"] == "rejected"

    # Verify case returns to ASSIGNED
    await test_db.refresh(case)
    assert case.status == CaseStatus.ASSIGNED


@pytest.mark.asyncio
async def test_list_pending_approvals_and_case_approvals(async_client: AsyncClient, test_db):
    """Test listing approvals for a case and querying pending approvals."""
    operator = User(
        email="op_list@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    lead = User(
        email="lead_list@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="Campus North",
        email_verified=True,
    )
    manager = User(
        email="mgr_list@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, lead, manager])
    await test_db.commit()

    now = datetime.now(timezone.utc)
    case = Case(
        reference_number="REQ-2026-000099",
        title="Multi-Approval Case",
        description="Testing approval history listing.",
        type=CaseType.SERVICE_REQUEST,
        priority=CasePriority.P3,
        status=CaseStatus.AWAITING_APPROVAL,
        requester_id=operator.id,
        site="Campus North",
        version=1,
        created_at=now,
    )
    test_db.add(case)
    await test_db.flush()

    appr1 = Approval(
        id=uuid.uuid4(),
        case_id=case.id,
        approver_id=lead.id,
        decision=ApprovalDecision.PENDING,
        created_at=now,
    )
    test_db.add(appr1)
    await test_db.commit()

    # List approvals for case
    op_token = make_token(operator)
    case_apprs_resp = await async_client.get(
        f"/api/v1/cases/{case.id}/approvals",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert case_apprs_resp.status_code == 200
    case_apprs = case_apprs_resp.json()
    assert len(case_apprs) == 1
    assert case_apprs[0]["id"] == str(appr1.id)

    # Lead queries pending -> sees 1
    lead_token = make_token(lead)
    lead_pending_resp = await async_client.get(
        "/api/v1/approvals/pending",
        headers={"Authorization": f"Bearer {lead_token}"},
    )
    assert lead_pending_resp.status_code == 200
    assert lead_pending_resp.json()["total"] == 1

    # Manager queries pending -> sees all platform pending
    mgr_token = make_token(manager)
    mgr_pending_resp = await async_client.get(
        "/api/v1/approvals/pending",
        headers={"Authorization": f"Bearer {mgr_token}"},
    )
    assert mgr_pending_resp.status_code == 200
    assert mgr_pending_resp.json()["total"] == 1
