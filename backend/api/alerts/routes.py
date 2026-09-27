from typing import List, Optional, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Depends, status, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db_session
from models.user import User
from models.enums import UserRole, AlertProvider, AlertStatus
from api.deps import get_current_active_user, require_roles
from schemas.alert import (
    InboundAlertResponse,
    AlertRuleCreate,
    AlertRuleResponse,
)
from services.alert_ingestion_service import AlertIngestionService

router = APIRouter(prefix="/integrations/alerts", tags=["Inbound Monitoring & Alerts"])


@router.post("/inbound/{provider}", response_model=InboundAlertResponse, status_code=status.HTTP_201_CREATED)
async def receive_inbound_alert(
    provider: AlertProvider,
    payload: Dict[str, Any],
    request: Request,
    org_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_db_session),
):
    """
    Inbound webhook receiver for APM & monitoring tools (Prometheus, Datadog, Sentry, CloudWatch, Generic).
    Validates inbound webhook signatures and tokens using constant-time verification.
    """
    headers = {k.lower(): v for k, v in request.headers.items()}
    query_params = dict(request.query_params)

    # 1. Authenticate inbound webhook request
    if not AlertIngestionService.verify_webhook_auth(provider, headers, query_params):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": {
                    "code": "WEBHOOK_UNAUTHORIZED",
                    "message": "Invalid or missing webhook authentication credentials.",
                }
            },
        )

    # 2. Extract tenant organization context
    header_org = headers.get("x-organization-id")
    target_org_id: Optional[UUID] = None
    if org_id:
        target_org_id = org_id
    elif header_org:
        try:
            target_org_id = UUID(header_org)
        except ValueError:
            target_org_id = None
    elif payload.get("organization_id"):
        try:
            target_org_id = UUID(str(payload.get("organization_id")))
        except ValueError:
            target_org_id = None

    alert = await AlertIngestionService.ingest_alert(
        db=db,
        provider=provider,
        payload=payload,
        organization_id=target_org_id,
    )
    return alert


@router.get("", response_model=List[InboundAlertResponse], status_code=status.HTTP_200_OK)
async def list_inbound_alerts(
    provider: Optional[AlertProvider] = None,
    alert_status: Optional[AlertStatus] = None,
    severity: Optional[str] = None,
    limit: int = 50,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Queries historical and active inbound monitoring alerts scoped to caller's organization.
    """
    return await AlertIngestionService.list_alerts(
        db=db,
        provider=provider,
        status=alert_status,
        severity=severity,
        organization_id=current_user.organization_id,
        limit=limit,
    )


@router.post("/{alert_id}/acknowledge", response_model=InboundAlertResponse, status_code=status.HTTP_200_OK)
async def acknowledge_alert(
    alert_id: UUID,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Marks an alert as acknowledged by an operator or team lead, enforcing tenant isolation.
    """
    alert = await AlertIngestionService.acknowledge_alert(
        db=db,
        alert_id=alert_id,
        user_id=current_user.id,
        user_organization_id=current_user.organization_id,
    )
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "ALERT_NOT_FOUND", "message": "Alert not found."}},
        )
    return alert


@router.post("/rules", response_model=AlertRuleResponse, status_code=status.HTTP_201_CREATED)
async def create_alert_rule(
    payload: AlertRuleCreate,
    current_user: User = Depends(
        require_roles([UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Creates an alert routing and auto-incident generation rule scoped to caller's organization.
    """
    return await AlertIngestionService.create_rule(
        db=db,
        name=payload.name,
        provider=payload.provider,
        match_severity=payload.match_severity,
        match_keyword=payload.match_keyword,
        auto_create_incident=payload.auto_create_incident,
        incident_priority=payload.incident_priority,
        target_team_id=payload.target_team_id,
        organization_id=current_user.organization_id,
    )


@router.get("/rules", response_model=List[AlertRuleResponse], status_code=status.HTTP_200_OK)
async def list_alert_rules(
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Lists all alert transformation and auto-incident rules scoped to caller's organization.
    """
    return await AlertIngestionService.list_rules(
        db=db,
        organization_id=current_user.organization_id,
    )

