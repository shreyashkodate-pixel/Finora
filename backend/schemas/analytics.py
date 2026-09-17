from typing import List, Dict
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class WorkloadForecastResponse(BaseModel):
    horizon_days: int
    forecast_date: datetime
    predicted_total_cases: int
    predicted_p1_cases: int
    predicted_p2_cases: int
    predicted_p3_p4_cases: int
    category_breakdown: Dict[str, int] = Field(default_factory=dict)
    confidence_interval: Dict[str, int] = Field(default_factory=dict)
    recommendation: str

    model_config = ConfigDict(from_attributes=True)


class PredictiveRiskItem(BaseModel):
    case_id: UUID
    reference_number: str
    title: str
    priority: str
    current_status: str
    predicted_breach_probability: float
    time_to_breach_minutes: int
    risk_drivers: List[str] = Field(default_factory=list)


class PredictiveRiskResponse(BaseModel):
    total_at_risk_cases: int
    high_risk_cases: List[PredictiveRiskItem] = Field(default_factory=list)
    ai_summary: str


class TeamCapacityMetricItem(BaseModel):
    team_id: UUID
    team_name: str
    active_operators: int
    open_cases: int
    avg_cases_per_operator: float
    capacity_utilization_pct: float
    burnout_risk: str  # low, moderate, high, critical
    estimated_closure_velocity_per_day: float


class TeamCapacityOverviewResponse(BaseModel):
    total_teams: int
    overall_utilization_pct: float
    teams: List[TeamCapacityMetricItem] = Field(default_factory=list)
