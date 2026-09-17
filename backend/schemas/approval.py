from datetime import datetime
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field

from models.enums import ApprovalDecision


class ApprovalRequestCreate(BaseModel):
    approver_id: UUID = Field(..., description="ID of the assigned approver (Lead, Manager, or Admin)")
    reason: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Reason or business justification for requiring approval",
    )


class ApprovalDecisionSubmit(BaseModel):
    decision: ApprovalDecision = Field(..., description="Decision: approved or rejected")
    reason: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Justification or feedback regarding the approval decision",
    )


class ApprovalOut(BaseModel):
    id: UUID
    case_id: UUID
    approver_id: UUID
    decision: ApprovalDecision
    reason: Optional[str] = None
    decided_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ApprovalListOut(BaseModel):
    items: List[ApprovalOut]
    total: int
