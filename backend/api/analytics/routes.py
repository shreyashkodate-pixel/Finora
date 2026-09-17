from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db_session
from models.user import User
from models.enums import UserRole
from api.deps import get_current_active_user, require_roles
from schemas.analytics import (
    WorkloadForecastResponse,
    PredictiveRiskResponse,
    TeamCapacityOverviewResponse,
)
from services.predictive_analytics_service import PredictiveAnalyticsService

router = APIRouter(prefix="/analytics", tags=["Predictive Analytics & Capacity"])


@router.get("/predictive/workload", response_model=WorkloadForecastResponse, status_code=status.HTTP_200_OK)
async def get_workload_forecast(
    horizon_days: int = Query(7, ge=1, le=90, description="Forecast horizon in days (e.g. 7 or 30)"),
    current_user: User = Depends(
        require_roles([UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Returns time-series workload forecasts, expected priority distributions, and staffing advice.
    """
    return await PredictiveAnalyticsService.generate_workload_forecast(
        db=db,
        horizon_days=horizon_days,
    )


@router.get("/predictive/risk-forecast", response_model=PredictiveRiskResponse, status_code=status.HTTP_200_OK)
async def get_predictive_risk_forecast(
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Identifies active tickets with statistically high likelihood of SLA breach.
    """
    return await PredictiveAnalyticsService.get_predictive_risk_forecast(db=db)


@router.get("/capacity/teams", response_model=TeamCapacityOverviewResponse, status_code=status.HTTP_200_OK)
async def get_team_capacity_overview(
    current_user: User = Depends(
        require_roles([UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Returns real-time operator caseload, capacity utilization %, and burnout risk index across teams.
    """
    return await PredictiveAnalyticsService.get_team_capacity_overview(db=db)
