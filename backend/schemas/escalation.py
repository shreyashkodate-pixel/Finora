from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

from models.enums import EscalationTrigger, EscalationStatus


class EscalationEventOut(BaseModel):
    id: UUID
    case_id: UUID
    trigger_reason: EscalationTrigger
    escalated_to_user_id: Optional[UUID] = None
    escalated_to_role: Optional[str] = None
    escalated_by: str
    status: EscalationStatus
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ManualEscalateRequest(BaseModel):
    reason: Optional[str] = Field(
        default=None,
        max_length=500,
        description="Optional reason for managerial assistance request",
    )


class SweepResultOut(BaseModel):
    cases_evaluated: int
    sla_warnings_emitted: int
    sla_breaches_detected: int
    escalations_raised: int
    escalations_promoted: int
    timestamp: datetime
