import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import create_access_token, hash_password
from models.user import User, Team
from models.case import Case
from models.enums import UserRole, CasePriority, CaseStatus, CaseType, ApprovalDecision, KnowledgeState
from models.organization import Organization, TenantPolicy
from models.problem_change import Problem, ChangeRequest, ProblemCaseLink, MajorIncident
from models.knowledge import KnowledgeArticle, Approval
from models.attachment import Attachment
from models.message import Message
from services.ai_service import triage_case


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


async def create_tenant(db: AsyncSession, name: str, slug: str, is_active: bool = True, policy_kwargs: dict = None):
    org = Organization(
        name=name,
        slug=slug,
        is_active=is_active,
        domain_whitelist=[f"{slug}.com"],
    )
    db.add(org)
    await db.flush()

    policy_data = {
        "organization_id": org.id,
        "allow_password_auth": True,
        "allow_google_oauth": True,
        "ai_auto_triage_enabled": True,
    }
    if policy_kwargs:
        policy_data.update(policy_kwargs)

    policy = TenantPolicy(**policy_data)
    db.add(policy)
    await db.flush()
    return org, policy


async def create_tenant_user(
    db: AsyncSession,
    email: str,
    org: Organization,
    role: UserRole = UserRole.REQUESTER,
    password: str = "SecretPassword123!",
):
    user = User(
        email=email,
        password_hash=hash_password(password),
        role=role,
        organization_id=org.id if org else None,
        site="HQ",
        email_verified=True,
    )
    db.add(user)
    await db.flush()
    return user


@pytest.mark.asyncio
async def test_case_tenant_isolation_and_creation(async_client: AsyncClient, test_db: AsyncSession):
    # Setup Tenant A and Tenant B
    org_a, _ = await create_tenant(test_db, "Tenant Alpha", "tenant-a")
    org_b, _ = await create_tenant(test_db, "Tenant Beta", "tenant-b")

    req_a = await create_tenant_user(test_db, "req_a@tenant-a.com", org_a, UserRole.REQUESTER)
    op_a = await create_tenant_user(test_db, "op_a@tenant-a.com", org_a, UserRole.OPERATOR)
    op_b = await create_tenant_user(test_db, "op_b@tenant-b.com", org_b, UserRole.OPERATOR)
    await test_db.commit()

    token_req_a = make_token(req_a)
    token_op_a = make_token(op_a)
    token_op_b = make_token(op_b)

    # 1. Requester A creates case -> should inherit org_a.id
    res_create = await async_client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {token_req_a}"},
        json={
            "title": "VPN issue on Tenant A",
            "description": "Cannot connect to VPN",
            "priority": "p2",
            "type": "incident",
        },
    )
    assert res_create.status_code == 201
    case_a_id = res_create.json()["id"]

    # 2. Operator A (Tenant A) lists cases -> sees case A
    res_list_a = await async_client.get(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {token_op_a}"},
    )
    assert res_list_a.status_code == 200
    cases_a = res_list_a.json()["items"]
    assert any(c["id"] == case_a_id for c in cases_a)

    # 3. Operator B (Tenant B) lists cases -> empty / cannot see case A
    res_list_b = await async_client.get(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {token_op_b}"},
    )
    assert res_list_b.status_code == 200
    cases_b = res_list_b.json()["items"]
    assert not any(c["id"] == case_a_id for c in cases_b)

    # 4. Operator B tries to GET case A -> 404
    res_get_b = await async_client.get(
        f"/api/v1/cases/{case_a_id}",
        headers={"Authorization": f"Bearer {token_op_b}"},
    )
    assert res_get_b.status_code == 404

    # 5. Operator B tries to PATCH case A -> 404
    res_patch_b = await async_client.patch(
        f"/api/v1/cases/{case_a_id}",
        headers={"Authorization": f"Bearer {token_op_b}"},
        json={"priority": "p1", "version": 1},
    )
    assert res_patch_b.status_code == 404


@pytest.mark.asyncio
async def test_case_assignment_cross_tenant_blocked(async_client: AsyncClient, test_db: AsyncSession):
    org_a, _ = await create_tenant(test_db, "Tenant Alpha", "tenant-a")
    org_b, _ = await create_tenant(test_db, "Tenant Beta", "tenant-b")

    lead_a = await create_tenant_user(test_db, "lead_a@tenant-a.com", org_a, UserRole.TEAM_LEAD)
    op_b = await create_tenant_user(test_db, "op_b@tenant-b.com", org_b, UserRole.OPERATOR)

    team_b = Team(name="Tenant B Network Team", organization_id=org_b.id)
    test_db.add(team_b)
    await test_db.flush()

    case_a = Case(
        title="Server outage",
        description="Database down",
        reference_number="INC-1001",
        requester_id=lead_a.id,
        organization_id=org_a.id,
        priority=CasePriority.P1,
        status=CaseStatus.NEW,
        type=CaseType.INCIDENT,
        version=1,
    )
    test_db.add(case_a)
    await test_db.commit()

    token_lead_a = make_token(lead_a)

    # Assign cross-tenant user -> 400
    res_assign_user = await async_client.patch(
        f"/api/v1/cases/{case_a.id}",
        headers={"Authorization": f"Bearer {token_lead_a}"},
        json={"owner_id": str(op_b.id), "version": 1},
    )
    assert res_assign_user.status_code == 400

    # Assign cross-tenant team -> 400
    res_assign_team = await async_client.patch(
        f"/api/v1/cases/{case_a.id}",
        headers={"Authorization": f"Bearer {token_lead_a}"},
        json={"team_id": str(team_b.id), "version": 1},
    )
    assert res_assign_team.status_code == 400


@pytest.mark.asyncio
async def test_problem_change_major_incident_tenant_isolation(async_client: AsyncClient, test_db: AsyncSession):
    org_a, _ = await create_tenant(test_db, "Tenant Alpha", "tenant-a")
    org_b, _ = await create_tenant(test_db, "Tenant Beta", "tenant-b")

    lead_a = await create_tenant_user(test_db, "lead_a@tenant-a.com", org_a, UserRole.TEAM_LEAD)
    lead_b = await create_tenant_user(test_db, "lead_b@tenant-b.com", org_b, UserRole.TEAM_LEAD)

    case_a = Case(
        title="Case Org A",
        description="Details",
        reference_number="INC-2001",
        requester_id=lead_a.id,
        organization_id=org_a.id,
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        type=CaseType.INCIDENT,
        version=1,
    )
    case_b = Case(
        title="Case Org B",
        description="Details",
        reference_number="INC-2002",
        requester_id=lead_b.id,
        organization_id=org_b.id,
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        type=CaseType.INCIDENT,
        version=1,
    )
    test_db.add_all([case_a, case_b])
    await test_db.commit()

    token_a = make_token(lead_a)
    token_b = make_token(lead_b)

    # 1. Lead A creates Problem
    res_prob = await async_client.post(
        "/api/v1/problems",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "title": "Recurring Memory Leak",
            "description": "Heap grows continuously",
            "priority": "p2",
            "workaround": "Restart container",
        },
    )
    assert res_prob.status_code == 201
    prob_a_id = res_prob.json()["id"]

    # 2. Lead B cannot retrieve Problem A
    res_prob_b = await async_client.get(
        f"/api/v1/problems/{prob_a_id}",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert res_prob_b.status_code == 404

    # 3. Lead A links Problem A to Case B (Tenant B) -> 400 rejected
    res_link_cross = await async_client.post(
        f"/api/v1/problems/{prob_a_id}/link-case",
        headers={"Authorization": f"Bearer {token_a}"},
        json={"case_id": str(case_b.id)},
    )
    assert res_link_cross.status_code in (400, 404)

    # 4. Lead A creates Change Request for Problem A -> OK
    res_change = await async_client.post(
        "/api/v1/changes",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "title": "Upgrade Memory Allocator",
            "description": "Fix leak in production",
            "reason": "Prevent OOM crashes",
            "change_type": "normal",
            "risk_level": "moderate",
            "implementation_plan": "Step 1: Deploy patch to cluster",
            "test_plan": "Step 2: Run benchmark suite",
            "rollback_plan": "Step 3: Revert container image",
            "problem_id": prob_a_id,
        },
    )
    assert res_change.status_code == 201
    change_a_id = res_change.json()["id"]

    # 5. Lead B cannot see Change A
    res_change_b = await async_client.get(
        f"/api/v1/changes/{change_a_id}",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert res_change_b.status_code == 404

    # 6. Lead B creates Change Request pointing to Problem A -> 400
    res_change_cross = await async_client.post(
        "/api/v1/changes",
        headers={"Authorization": f"Bearer {token_b}"},
        json={
            "title": "Malicious cross-tenant change",
            "description": "Ref foreign problem",
            "reason": "Exploit attempt",
            "change_type": "normal",
            "risk_level": "low",
            "implementation_plan": "Step 1: Deploy patch",
            "test_plan": "Step 2: Run benchmark",
            "rollback_plan": "Step 3: Revert image",
            "problem_id": prob_a_id,
        },
    )
    assert res_change_cross.status_code == 400

    # 7. Major Incident declaration cross-tenant check
    res_mi_cross = await async_client.post(
        "/api/v1/major-incidents",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "case_id": str(case_b.id),
            "title": "Outage Incident Declaration",
            "impact_summary": "Attempt cross-tenant MI declaration",
        },
    )
    assert res_mi_cross.status_code == 404


@pytest.mark.asyncio
async def test_knowledge_and_approval_tenant_isolation(async_client: AsyncClient, test_db: AsyncSession):
    org_a, _ = await create_tenant(test_db, "Tenant Alpha", "tenant-a")
    org_b, _ = await create_tenant(test_db, "Tenant Beta", "tenant-b")

    lead_a = await create_tenant_user(test_db, "lead_a@tenant-a.com", org_a, UserRole.TEAM_LEAD)
    lead_b = await create_tenant_user(test_db, "lead_b@tenant-b.com", org_b, UserRole.TEAM_LEAD)
    mgr_b = await create_tenant_user(test_db, "mgr_b@tenant-b.com", org_b, UserRole.MANAGER)

    case_a = Case(
        title="Case Org A",
        description="Details",
        reference_number="INC-3001",
        requester_id=lead_a.id,
        organization_id=org_a.id,
        priority=CasePriority.P2,
        status=CaseStatus.ASSIGNED,
        type=CaseType.INCIDENT,
        version=1,
    )
    test_db.add(case_a)
    await test_db.commit()

    token_a = make_token(lead_a)
    token_b = make_token(lead_b)

    # 1. Knowledge Article created by Tenant A
    res_kb = await async_client.post(
        "/api/v1/knowledge",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "title": "Secret Internal Procedure",
            "body": "# Step 1: Rotate keys\nDetailed confidential instructions here.",
            "state": "draft",
            "source_case_id": str(case_a.id),
        },
    )
    assert res_kb.status_code == 201
    article_id = res_kb.json()["id"]

    # 2. Tenant B lists articles -> cannot see internal article
    res_kb_list = await async_client.get(
        "/api/v1/knowledge",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert res_kb_list.status_code == 200
    assert not any(a["id"] == article_id for a in res_kb_list.json()["items"])

    # 3. Tenant B gets article -> 404
    res_kb_get = await async_client.get(
        f"/api/v1/knowledge/{article_id}",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert res_kb_get.status_code == 404

    # 4. Approval request with cross-tenant approver -> 400
    res_appr_cross = await async_client.post(
        f"/api/v1/cases/{case_a.id}/approvals",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "approver_id": str(mgr_b.id),
            "reason": "Requesting budget increase",
        },
    )
    assert res_appr_cross.status_code == 400


@pytest.mark.asyncio
async def test_organization_admin_isolation(async_client: AsyncClient, test_db: AsyncSession):
    org_a, _ = await create_tenant(test_db, "Tenant Alpha", "tenant-a")
    org_b, _ = await create_tenant(test_db, "Tenant Beta", "tenant-b")

    admin_a = await create_tenant_user(test_db, "admin_a@tenant-a.com", org_a, UserRole.ADMINISTRATOR)
    admin_b = await create_tenant_user(test_db, "admin_b@tenant-b.com", org_b, UserRole.ADMINISTRATOR)
    op_a = await create_tenant_user(test_db, "op_a@tenant-a.com", org_a, UserRole.OPERATOR)
    await test_db.commit()

    token_admin_a = make_token(admin_a)
    token_op_a = make_token(op_a)

    # 1. Non-admin accessing org admin endpoint -> 403
    res_op = await async_client.get(
        f"/api/v1/admin/organizations/{org_a.id}",
        headers={"Authorization": f"Bearer {token_op_a}"},
    )
    assert res_op.status_code == 403

    # 2. Admin A accessing Org B details -> 404 (scoped to own org)
    res_foreign_org = await async_client.get(
        f"/api/v1/admin/organizations/{org_b.id}",
        headers={"Authorization": f"Bearer {token_admin_a}"},
    )
    assert res_foreign_org.status_code == 404

    # 3. Admin A accessing Org B stats -> 404
    res_foreign_stats = await async_client.get(
        f"/api/v1/admin/organizations/{org_b.id}/stats",
        headers={"Authorization": f"Bearer {token_admin_a}"},
    )
    assert res_foreign_stats.status_code == 404

    # 4. Admin A patching Org B policy -> 404
    res_foreign_patch = await async_client.patch(
        f"/api/v1/admin/organizations/{org_b.id}/policy",
        headers={"Authorization": f"Bearer {token_admin_a}"},
        json={"data_retention_days": 90},
    )
    assert res_foreign_patch.status_code == 404

    # 5. Admin A accessing GET /admin/organizations/me -> 200 with Org A
    res_me = await async_client.get(
        "/api/v1/admin/organizations/me",
        headers={"Authorization": f"Bearer {token_admin_a}"},
    )
    assert res_me.status_code == 200
    assert res_me.json()["id"] == str(org_a.id)


@pytest.mark.asyncio
async def test_inactive_organization_and_tenant_policy_enforcement(async_client: AsyncClient, test_db: AsyncSession):
    # 1. Inactive organization login attempt -> 403
    org_inactive, _ = await create_tenant(test_db, "Inactive Org", "inactive-org", is_active=False)
    user_inactive = await create_tenant_user(test_db, "user@inactive-org.com", org_inactive)
    await test_db.commit()

    res_login_inactive = await async_client.post(
        "/api/v1/auth/login",
        json={"email": "user@inactive-org.com", "password": "SecretPassword123!"},
    )
    assert res_login_inactive.status_code == 403
    assert "deactivated" in res_login_inactive.json()["error"]["message"]

    # 2. Policy allow_password_auth = False
    org_no_pw, _ = await create_tenant(
        test_db,
        "No PW Org",
        "no-pw-org",
        is_active=True,
        policy_kwargs={"allow_password_auth": False},
    )
    user_no_pw = await create_tenant_user(test_db, "user@no-pw-org.com", org_no_pw)
    await test_db.commit()

    res_login_no_pw = await async_client.post(
        "/api/v1/auth/login",
        json={"email": "user@no-pw-org.com", "password": "SecretPassword123!"},
    )
    assert res_login_no_pw.status_code == 403
    assert "disabled" in res_login_no_pw.json()["error"]["message"]

    # 3. AI auto-triage policy disabled
    org_no_ai, _ = await create_tenant(
        test_db,
        "No AI Org",
        "no-ai-org",
        is_active=True,
        policy_kwargs={"ai_auto_triage_enabled": False},
    )
    req_no_ai = await create_tenant_user(test_db, "req@no-ai-org.com", org_no_ai)
    case_no_ai = Case(
        title="Laptop frozen",
        description="Screen is blue",
        reference_number="INC-4001",
        requester_id=req_no_ai.id,
        organization_id=org_no_ai.id,
        priority=CasePriority.P3,
        status=CaseStatus.NEW,
        type=CaseType.INCIDENT,
        version=1,
    )
    test_db.add(case_no_ai)
    await test_db.commit()

    triage_res = await triage_case(test_db, case_no_ai.id)
    assert triage_res is None  # Should skip because policy disabled it
