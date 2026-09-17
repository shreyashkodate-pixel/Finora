from typing import List, Optional
from uuid import UUID
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc

from models.organization import Organization, TenantPolicy
from models.user import User, Team
from models.case import Case
from schemas.organization import TenantPolicyUpdate, OrganizationStatsResponse


class OrganizationService:
    @staticmethod
    async def create_organization(
        db: AsyncSession,
        name: str,
        slug: str,
        domain_whitelist: List[str],
        sla_tier: str = "enterprise",
        max_users: int = 500,
    ) -> Organization:
        """
        Creates a new tenant organization along with its default governance policy.
        """
        # Check uniqueness
        stmt_check = select(Organization).where(
            (Organization.name == name) | (Organization.slug == slug)
        )
        res = await db.execute(stmt_check)
        if res.scalars().first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "ORGANIZATION_EXISTS", "message": "An organization with this name or slug already exists."}},
            )

        org = Organization(
            name=name,
            slug=slug.lower().strip(),
            domain_whitelist=domain_whitelist,
            sla_tier=sla_tier,
            max_users=max_users,
        )
        db.add(org)
        await db.flush()

        policy = TenantPolicy(
            organization_id=org.id,
            data_retention_days=365,
            require_mfa=False,
            allow_password_auth=True,
            allow_google_oauth=True,
            ai_auto_triage_enabled=True,
            ai_autofix_enabled=True,
        )
        db.add(policy)
        await db.commit()
        await db.refresh(org)
        return org

    @staticmethod
    async def list_organizations(db: AsyncSession) -> List[Organization]:
        stmt = select(Organization).order_by(desc(Organization.created_at))
        res = await db.execute(stmt)
        return list(res.scalars().all())

    @staticmethod
    async def get_organization(db: AsyncSession, org_id: UUID) -> Optional[Organization]:
        stmt = select(Organization).where(Organization.id == org_id)
        res = await db.execute(stmt)
        return res.scalars().first()

    @staticmethod
    async def update_tenant_policy(
        db: AsyncSession,
        org_id: UUID,
        updates: TenantPolicyUpdate,
    ) -> TenantPolicy:
        stmt = select(TenantPolicy).where(TenantPolicy.organization_id == org_id)
        res = await db.execute(stmt)
        policy = res.scalars().first()
        if not policy:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "POLICY_NOT_FOUND", "message": "Tenant policy not found."}},
            )

        update_dict = updates.model_dump(exclude_unset=True)
        for k, v in update_dict.items():
            setattr(policy, k, v)

        await db.commit()
        await db.refresh(policy)
        return policy

    @staticmethod
    async def get_organization_stats(db: AsyncSession, org_id: UUID) -> OrganizationStatsResponse:
        org = await OrganizationService.get_organization(db, org_id)
        if not org:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "ORGANIZATION_NOT_FOUND", "message": "Organization not found."}},
            )

        stmt_users = select(func.count(User.id)).where(User.organization_id == org_id)
        total_users = (await db.execute(stmt_users)).scalar() or 0

        stmt_teams = select(func.count(Team.id)).where(Team.organization_id == org_id)
        total_teams = (await db.execute(stmt_teams)).scalar() or 0

        stmt_cases = select(func.count(Case.id)).where(Case.organization_id == org_id)
        total_cases = (await db.execute(stmt_cases)).scalar() or 0

        return OrganizationStatsResponse(
            organization_id=org.id,
            name=org.name,
            slug=org.slug,
            total_users=total_users,
            total_teams=total_teams,
            total_cases=total_cases,
            is_active=org.is_active,
        )
