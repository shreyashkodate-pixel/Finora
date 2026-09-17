import uuid
import pytest
from httpx import AsyncClient

from core.security import create_access_token
from models.case import Case
from models.enums import CasePriority, CaseStatus, CaseType, UserRole
from models.user import User


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_ai_draft_knowledge_from_case(async_client: AsyncClient, test_db):
    operator = User(
        email="operator_kbp@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester = User(
        email="req_kbp@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-7701",
        title="Thunderbolt Dock Dual Display Flickering",
        description="Monitors disconnect when charging laptop above 85W.",
        type=CaseType.INCIDENT,
        status=CaseStatus.RESOLVED,
        priority=CasePriority.P3,
        requester_id=requester.id,
        site="Campus North",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)

    # 1. Staff requests AI knowledge draft
    resp = await async_client.post(
        f"/api/v1/knowledge/ai/draft-from-case/{case.id}",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "How to Resolve: Thunderbolt Dock" in data["title"]
    assert "## Overview" in data["body"]
    assert "## Symptoms" in data["body"]
    assert "## Step-by-Step Resolution" in data["body"]
    assert data["source_case_id"] == str(case.id)


@pytest.mark.asyncio
async def test_case_audit_pdf_generation_and_access_control(async_client: AsyncClient, test_db):
    operator = User(
        email="operator_pdf@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    requester_owner = User(
        email="owner_pdf@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    requester_other = User(
        email="other_pdf@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="Campus North",
        email_verified=True,
    )
    test_db.add_all([operator, requester_owner, requester_other])
    await test_db.commit()

    case = Case(
        reference_number="INC-2026-7702",
        title="Outlook Certificate Expired",
        description="TLS handshake failed for mail.corp.net.",
        type=CaseType.INCIDENT,
        status=CaseStatus.RESOLVED,
        priority=CasePriority.P2,
        requester_id=requester_owner.id,
        site="Campus North",
    )
    test_db.add(case)
    await test_db.commit()

    op_token = make_token(operator)
    owner_token = make_token(requester_owner)
    other_token = make_token(requester_other)

    # 1. Owner requester downloads PDF
    resp_owner = await async_client.get(
        f"/api/v1/reports/pdf/cases/{case.id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert resp_owner.status_code == 200
    assert resp_owner.headers["content-type"] == "application/pdf"
    assert resp_owner.content.startswith(b"%PDF-")

    # 2. Staff downloads PDF
    resp_op = await async_client.get(
        f"/api/v1/reports/pdf/cases/{case.id}",
        headers={"Authorization": f"Bearer {op_token}"},
    )
    assert resp_op.status_code == 200
    assert resp_op.content.startswith(b"%PDF-")

    # 3. Unauthorized requester denied
    resp_other = await async_client.get(
        f"/api/v1/reports/pdf/cases/{case.id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert resp_other.status_code == 403


@pytest.mark.asyncio
async def test_executive_summary_pdf_generation(async_client: AsyncClient, test_db):
    manager = User(
        email="mgr_pdf@example.com",
        password_hash="hash",
        role=UserRole.MANAGER,
        site="HQ",
        email_verified=True,
    )
    requester = User(
        email="req_pdf@example.com",
        password_hash="hash",
        role=UserRole.REQUESTER,
        site="HQ",
        email_verified=True,
    )
    test_db.add_all([manager, requester])
    await test_db.commit()

    mgr_token = make_token(manager)
    req_token = make_token(requester)

    # 1. Manager downloads executive summary PDF
    resp = await async_client.get(
        "/api/v1/reports/pdf/executive-summary",
        headers={"Authorization": f"Bearer {mgr_token}"},
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/pdf"
    assert resp.content.startswith(b"%PDF-")

    # 2. Requester blocked from executive report
    bad_resp = await async_client.get(
        "/api/v1/reports/pdf/executive-summary",
        headers={"Authorization": f"Bearer {req_token}"},
    )
    assert bad_resp.status_code == 403
