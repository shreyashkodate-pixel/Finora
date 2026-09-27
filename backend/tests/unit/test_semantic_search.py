import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import create_access_token
from models.user import User
from models.enums import UserRole


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_index_entity_and_semantic_vector_search(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_search@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    await test_db.refresh(operator)
    token = make_token(operator)

    article_id = uuid.uuid4()
    # 1. Index a knowledge article
    index_res = await async_client.post(
        "/api/v1/search/index",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "entity_type": "knowledge_article",
            "entity_id": str(article_id),
            "title": "Global VPN Gateway Configuration & Troubleshooting",
            "content": "To connect to GlobalProtect VPN, enter vpn.corp.internal and use your LDAP credentials. If connection fails, flush your DNS cache and verify gateway certificate.",
            "metadata": {"state": "published", "category": "Network"},
        },
    )
    assert index_res.status_code == 201
    assert index_res.json()["status"] == "indexed"

    # 2. Perform semantic search
    search_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "query": "How do I connect to the corporate VPN gateway with LDAP?",
            "limit": 5,
            "min_score": 0.1,
        },
    )
    assert search_res.status_code == 200
    data = search_res.json()
    assert data["total_results"] >= 1
    top_hit = data["results"][0]
    assert top_hit["entity_type"] == "knowledge_article"
    assert "VPN" in top_hit["title"]
    assert top_hit["score"] > 0.3


@pytest.mark.asyncio
async def test_requester_isolation_in_semantic_search(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_iso@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="requester_iso@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()
    await test_db.refresh(operator)
    await test_db.refresh(requester)

    op_token = make_token(operator)
    req_token = make_token(requester)

    case_a_id = uuid.uuid4()
    other_requester_id = uuid.uuid4()

    # Index case for another requester
    await async_client.post(
        "/api/v1/search/index",
        headers={"Authorization": f"Bearer {op_token}"},
        json={
            "entity_type": "case",
            "entity_id": str(case_a_id),
            "title": "Confidential Salary Dispute Ticket",
            "content": "Discrepancy in monthly payroll compensation for executive employee.",
            "metadata": {"requester_id": str(other_requester_id), "status": "ASSIGNED"},
        },
    )

    # Requester searches for salary ticket
    req_search = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {req_token}"},
        json={
            "query": "Confidential Salary Dispute Payroll",
            "min_score": 0.05,
        },
    )
    assert req_search.status_code == 200
    # The confidential case should NOT be in requester's results
    case_ids = [r["entity_id"] for r in req_search.json()["results"]]
    assert str(case_a_id) not in case_ids


@pytest.mark.asyncio
async def test_nl_query_and_citations_synthesis(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_nl@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    await test_db.refresh(operator)
    op_token = make_token(operator)

    # Perform Natural Language Q&A
    nl_res = await async_client.post(
        "/api/v1/search/nl-query",
        headers={"Authorization": f"Bearer {op_token}"},
        json={
            "query": "How to resolve VPN gateway authentication errors?",
        },
    )
    assert nl_res.status_code == 200
    nl_data = nl_res.json()
    assert "answer" in nl_data
    assert len(nl_data["answer"]) > 20
    assert "citations" in nl_data

    # Check query history
    hist_res = await async_client.get(
        "/api/v1/search/history",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert hist_res.status_code == 200
    hist_data = hist_res.json()
    assert len(hist_data) >= 1
    assert hist_data[0]["query_text"] == "How to resolve VPN gateway authentication errors?"


@pytest.mark.asyncio
async def test_audit_log_authorization_strict_rbac(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    admin = User(
        email="admin_audit@example.com",
        password_hash="hash",
        role=UserRole.ADMINISTRATOR,
        site="HQ",
        email_verified=True,
    )
    manager = User(
        email="manager_audit@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="HQ",
        email_verified=True,
    )
    team_lead = User(
        email="lead_audit@example.com",
        password_hash="hash",
        role=UserRole.TEAM_LEAD,
        site="HQ",
        email_verified=True,
    )
    operator = User(
        email="operator_audit@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="HQ",
        email_verified=True,
    )
    requester = User(
        email="requester_audit@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="HQ",
        email_verified=True,
    )
    test_db.add_all([admin, manager, team_lead, operator, requester])
    await test_db.commit()
    for u in [admin, manager, team_lead, operator, requester]:
        await test_db.refresh(u)

    admin_token = make_token(admin)
    manager_token = make_token(manager)
    lead_token = make_token(team_lead)
    op_token = make_token(operator)
    req_token = make_token(requester)

    audit_id = uuid.uuid4()
    # 1. Index an audit log entry
    await async_client.post(
        "/api/v1/search/index",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "entity_type": "audit_log",
            "entity_id": str(audit_id),
            "title": "Confidential Executive Privilege Escalation Audit Event",
            "content": "Administrator elevated access keys for database disaster recovery.",
            "metadata": {"action": "PRIVILEGE_ESCALATION", "severity": "HIGH"},
        },
    )

    query_payload = {
        "query": "Privilege Escalation Audit Event",
        "entity_types": ["audit_log"],
        "min_score": 0.05,
    }

    # 2. Administrator CAN search and receive audit logs
    admin_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {admin_token}"},
        json=query_payload,
    )
    assert admin_res.status_code == 200
    admin_ids = [r["entity_id"] for r in admin_res.json()["results"]]
    assert str(audit_id) in admin_ids

    # 3. Manager CANNOT retrieve audit logs
    mgr_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {manager_token}"},
        json=query_payload,
    )
    assert mgr_res.status_code == 200
    mgr_ids = [r["entity_id"] for r in mgr_res.json()["results"]]
    assert str(audit_id) not in mgr_ids

    # 4. Team Lead CANNOT retrieve audit logs
    lead_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {lead_token}"},
        json=query_payload,
    )
    assert lead_res.status_code == 200
    lead_ids = [r["entity_id"] for r in lead_res.json()["results"]]
    assert str(audit_id) not in lead_ids

    # 5. Operator CANNOT retrieve audit logs
    op_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {op_token}"},
        json=query_payload,
    )
    assert op_res.status_code == 200
    op_ids = [r["entity_id"] for r in op_res.json()["results"]]
    assert str(audit_id) not in op_ids

    # 6. Requester CANNOT retrieve audit logs
    req_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {req_token}"},
        json=query_payload,
    )
    assert req_res.status_code == 200
    req_ids = [r["entity_id"] for r in req_res.json()["results"]]
    assert str(audit_id) not in req_ids


@pytest.mark.asyncio
async def test_tenant_isolation_in_semantic_search_and_nl_query(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    tenant_a_id = uuid.uuid4()
    tenant_b_id = uuid.uuid4()

    user_tenant_a = User(
        email="operator_tenant_a@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        organization_id=tenant_a_id,
        site="Campus A",
        email_verified=True,
    )
    user_tenant_b = User(
        email="operator_tenant_b@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        organization_id=tenant_b_id,
        site="Campus B",
        email_verified=True,
    )
    test_db.add_all([user_tenant_a, user_tenant_b])
    await test_db.commit()
    await test_db.refresh(user_tenant_a)
    await test_db.refresh(user_tenant_b)

    token_a = make_token(user_tenant_a)
    token_b = make_token(user_tenant_b)

    secret_doc_b_id = uuid.uuid4()

    # Index secret document belonging exclusively to Tenant B
    await async_client.post(
        "/api/v1/search/index",
        headers={"Authorization": f"Bearer {token_b}"},
        json={
            "entity_type": "knowledge_article",
            "entity_id": str(secret_doc_b_id),
            "title": "Tenant B Proprietary Cloud Infrastructure Architecture",
            "content": "Confidential Kubernetes cluster deployment instructions for Tenant B enterprise clients.",
            "metadata": {"state": "published", "organization_id": str(tenant_b_id)},
        },
    )

    # 1. User from Tenant A searches for Tenant B document
    search_a = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "query": "Tenant B Proprietary Cloud Infrastructure",
            "min_score": 0.05,
        },
    )
    assert search_a.status_code == 200
    results_a = search_a.json()["results"]
    ids_a = [r["entity_id"] for r in results_a]
    assert str(secret_doc_b_id) not in ids_a

    # 2. User from Tenant A asks NL query: Tenant B document must NOT appear in citations
    nl_a = await async_client.post(
        "/api/v1/search/nl-query",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "query": "Tenant B Proprietary Cloud Infrastructure",
        },
    )
    assert nl_a.status_code == 200
    citation_ids_a = [c["entity_id"] for c in nl_a.json()["citations"]]
    assert str(secret_doc_b_id) not in citation_ids_a

    # 3. User from Tenant B CAN retrieve Tenant B document
    search_b = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {token_b}"},
        json={
            "query": "Tenant B Proprietary Cloud Infrastructure",
            "min_score": 0.05,
        },
    )
    assert search_b.status_code == 200
    ids_b = [r["entity_id"] for r in search_b.json()["results"]]
    assert str(secret_doc_b_id) in ids_b


@pytest.mark.asyncio
async def test_unsupported_entity_type_rejection(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    admin = User(
        email="admin_unsupported@example.com",
        password_hash="hash",
        role=UserRole.ADMINISTRATOR,
        site="HQ",
        email_verified=True,
    )
    test_db.add(admin)
    await test_db.commit()
    await test_db.refresh(admin)
    token = make_token(admin)

    unknown_id = uuid.uuid4()
    # Direct DB injection or custom entity
    await async_client.post(
        "/api/v1/search/index",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "entity_type": "arbitrary_custom_table",
            "entity_id": str(unknown_id),
            "title": "Secret Internal Memory Dump",
            "content": "Raw memory dump containing tokens.",
            "metadata": {},
        },
    )

    # Search should ignore/reject unknown entity types
    search_res = await async_client.post(
        "/api/v1/search/semantic",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "query": "Secret Internal Memory Dump",
            "min_score": 0.05,
        },
    )
    assert search_res.status_code == 200
    ids = [r["entity_id"] for r in search_res.json()["results"]]
    assert str(unknown_id) not in ids

