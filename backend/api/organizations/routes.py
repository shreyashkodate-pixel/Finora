from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db_session
from models.user import User
from models.enums import UserRole
from api.deps import get_current_active_user, require_roles
from schemas.organization import (
    OrganizationCreate,
    OrganizationResponse,
    TenantPolicyUpdate,
    TenantPolicyResponse,
    OrganizationStatsResponse,
)
from services.organization_service import OrganizationService

router = APIRouter(prefix="/admin/organizations", tags=["Multi-Tenancy & Organizations"])


@router.post("", response_model=OrganizationResponse, status_code=status.HTTP_201_CREATED)
async def create_organization(
    payload: OrganizationCreate,
    current_user: User = Depends(require_roles([UserRole.ADMINISTRATOR])),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Creates a new multi-tenant organization with default security and data retention policies.
    """
    return await OrganizationService.create_organization(
        db=db,
        name=payload.name,
        slug=payload.slug,
        domain_whitelist=payload.domain_whitelist,
        sla_tier=payload.sla_tier,
        max_users=payload.max_users,
    )


@router.get("/me", response_model=OrganizationResponse, status_code=status.HTTP_200_OK)
async def get_my_organization(
    current_user: User = Depends(require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Retrieves the current user's authenticated organization and policy.
    """
    if not current_user.organization_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NO_ORGANIZATION", "message": "User is not associated with an organization."}},
        )
    org = await OrganizationService.get_organization(db=db, org_id=current_user.organization_id)
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "ORGANIZATION_NOT_FOUND", "message": "Organization not found."}},
        )
    return org


@router.get("", response_model=List[OrganizationResponse], status_code=status.HTTP_200_OK)
async def list_organizations(
    current_user: User = Depends(require_roles([UserRole.MANAGER, UserRole.ADMINISTRATOR])),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Lists tenant organizations scoped to current user.
    """
    return await OrganizationService.list_organizations(db=db, current_org_id=current_user.organization_id)


@router.get("/{org_id}", response_model=OrganizationResponse, status_code=status.HTTP_200_OK)
async def get_organization(
    org_id: UUID,
    current_user: User = Depends(require_roles([UserRole.MANAGER, UserRole.ADMINISTRATOR])),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Retrieves organization details including active policy settings.
    """
    if current_user.organization_id and current_user.organization_id != org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "ORGANIZATION_NOT_FOUND", "message": "Organization not found."}},
        )
    org = await OrganizationService.get_organization(db=db, org_id=org_id)
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "ORGANIZATION_NOT_FOUND", "message": "Organization not found."}},
        )
    return org


@router.get("/{org_id}/stats", response_model=OrganizationStatsResponse, status_code=status.HTTP_200_OK)
async def get_organization_stats(
    org_id: UUID,
    current_user: User = Depends(require_roles([UserRole.MANAGER, UserRole.ADMINISTRATOR])),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Returns user, team, and case metric counts for the given tenant organization.
    """
    if current_user.organization_id and current_user.organization_id != org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "ORGANIZATION_NOT_FOUND", "message": "Organization not found."}},
        )
    return await OrganizationService.get_organization_stats(db=db, org_id=org_id)


@router.patch("/{org_id}/policy", response_model=TenantPolicyResponse, status_code=status.HTTP_200_OK)
async def update_tenant_policy(
    org_id: UUID,
    payload: TenantPolicyUpdate,
    current_user: User = Depends(require_roles([UserRole.ADMINISTRATOR])),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Updates tenant data retention, auth provider access, and AI feature toggles.
    """
    if current_user.organization_id and current_user.organization_id != org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "ORGANIZATION_NOT_FOUND", "message": "Organization not found."}},
        )
    return await OrganizationService.update_tenant_policy(
        db=db,
        org_id=org_id,
        updates=payload,
    )
