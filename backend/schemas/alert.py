from typing import Optional, Dict, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

from models.enums import AlertProvider, AlertStatus, CasePriority


class InboundAlertResponse(BaseModel):
    id: UUID
    provider: AlertProvider
    external_alert_id: Optional[str] = None
    title: str
    severity: str
    description: Optional[str] = None
    fingerprint: str
    status: AlertStatus
    raw_payload: Dict[str, Any] = Field(default_factory=dict)
    case_id: Optional[UUID] = None
    acknowledged_at: Optional[datetime] = None
    acknowledged_by_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AlertRuleCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    provider: AlertProvider = AlertProvider.GENERIC
    match_severity: Optional[str] = None  # e.g., "critical", "error", "warning"
    match_keyword: Optional[str] = None
    auto_create_incident: bool = True
    incident_priority: CasePriority = CasePriority.P2
    target_team_id: Optional[UUID] = None


class AlertRuleResponse(BaseModel):
    id: UUID
    name: str
    provider: AlertProvider
    match_severity: Optional[str] = None
    match_keyword: Optional[str] = None
    auto_create_incident: bool
    incident_priority: CasePriority
    target_team_id: Optional[UUID] = None
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
