import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import create_access_token
from models.user import User, Team
from models.enums import UserRole


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_organization_creation_and_policy_initialization(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    admin = User(
        email="admin_org@example.com",
        password_hash="hash",
        role=UserRole.ADMINISTRATOR,
        site="HQ",
        email_verified=True,
    )
    test_db.add(admin)
    await test_db.commit()
    await test_db.refresh(admin)
    token = make_token(admin)

    res = await async_client.post(
        "/api/v1/admin/organizations",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Acme Global Industries",
            "slug": "acme-global",
            "domain_whitelist": ["acme.com", "global.acme.com"],
            "sla_tier": "enterprise",
            "max_users": 1000,
        },
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Acme Global Industries"
    assert data["slug"] == "acme-global"
    assert data["policy"] is not None
    assert data["policy"]["data_retention_days"] == 365
    assert data["policy"]["ai_auto_triage_enabled"] is True


@pytest.mark.asyncio
async def test_tenant_policy_update(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    admin = User(
        email="admin_policy@example.com",
        password_hash="hash",
        role=UserRole.ADMINISTRATOR,
        site="HQ",
        email_verified=True,
    )
    test_db.add(admin)
    await test_db.commit()
    await test_db.refresh(admin)
    token = make_token(admin)

    # 1. Create org
    create_res = await async_client.post(
        "/api/v1/admin/organizations",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "CyberTech Security",
            "slug": "cybertech",
            "domain_whitelist": ["cybertech.io"],
        },
    )
    assert create_res.status_code == 201
    org_id = create_res.json()["id"]

    # 2. Update policy
    patch_res = await async_client.patch(
        f"/api/v1/admin/organizations/{org_id}/policy",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "data_retention_days": 180,
            "require_mfa": True,
            "ai_autofix_enabled": False,
        },
    )
    assert patch_res.status_code == 200
    p_data = patch_res.json()
    assert p_data["data_retention_days"] == 180
    assert p_data["require_mfa"] is True
    assert p_data["ai_autofix_enabled"] is False


@pytest.mark.asyncio
async def test_organization_stats(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    admin = User(
        email="admin_stats@example.com",
        password_hash="hash",
        role=UserRole.ADMINISTRATOR,
        site="HQ",
        email_verified=True,
    )
    test_db.add(admin)
    await test_db.commit()
    await test_db.refresh(admin)
    token = make_token(admin)

    # Create org
    create_res = await async_client.post(
        "/api/v1/admin/organizations",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Fintech Innovations",
            "slug": "fintech-innovations",
        },
    )
    assert create_res.status_code == 201
    org_id = uuid.UUID(create_res.json()["id"])

    # Create user and team bound to org
    team = Team(name="Fintech SecOps", organization_id=org_id)
    operator = User(
        email="fintech_op@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="HQ",
        organization_id=org_id,
        email_verified=True,
    )
    test_db.add_all([team, operator])
    await test_db.commit()

    # Query stats
    stats_res = await async_client.get(
        f"/api/v1/admin/organizations/{org_id}/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert stats_res.status_code == 200
    s_data = stats_res.json()
    assert s_data["total_users"] == 1
    assert s_data["total_teams"] == 1
