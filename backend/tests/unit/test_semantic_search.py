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
