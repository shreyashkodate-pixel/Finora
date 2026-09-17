import uuid
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field

from models.enums import (
    ProblemStatus,
    CasePriority,
    ChangeType,
    ChangeStatus,
    RiskLevel,
    MajorIncidentStatus,
)


# ==========================================
# Known Error (KEDB) Schemas
# ==========================================
class KnownErrorCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=3, max_length=255)
    symptoms: str = Field(..., min_length=5)
    workaround: str = Field(..., min_length=5)
    permanent_fix: Optional[str] = None
    published: bool = True


class KnownErrorUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = Field(None, min_length=3, max_length=255)
    symptoms: Optional[str] = None
    workaround: Optional[str] = None
    permanent_fix: Optional[str] = None
    published: Optional[bool] = None


class KnownErrorOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    problem_id: uuid.UUID
    title: str
    symptoms: str
    workaround: str
    permanent_fix: Optional[str] = None
    published: bool
    created_at: datetime
    updated_at: datetime


# ==========================================
# Problem Management Schemas
# ==========================================
class ProblemCaseLinkCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    case_id: uuid.UUID


class ProblemCaseLinkOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    problem_id: uuid.UUID
    case_id: uuid.UUID
    linked_by: Optional[uuid.UUID] = None
    linked_at: datetime


class ProblemCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=3, max_length=255)
    description: str = Field(..., min_length=5)
    priority: CasePriority = CasePriority.P3
    root_cause: Optional[str] = None
    workaround: Optional[str] = None
    owner_id: Optional[uuid.UUID] = None
    case_ids: Optional[List[uuid.UUID]] = None


class ProblemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = Field(None, min_length=3, max_length=255)
    description: Optional[str] = None
    status: Optional[ProblemStatus] = None
    priority: Optional[CasePriority] = None
    root_cause: Optional[str] = None
    workaround: Optional[str] = None
    owner_id: Optional[uuid.UUID] = None


class ProblemOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    problem_number: str
    title: str
    description: str
    root_cause: Optional[str] = None
    workaround: Optional[str] = None
    status: ProblemStatus
    priority: CasePriority
    owner_id: Optional[uuid.UUID] = None
    created_at: datetime
    updated_at: datetime
    resolved_at: Optional[datetime] = None
    case_links: List[ProblemCaseLinkOut] = []
    known_errors: List[KnownErrorOut] = []


# ==========================================
# Change Management Schemas
# ==========================================
class ChangeRequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=3, max_length=255)
    description: str = Field(..., min_length=5)
    reason: str = Field(..., min_length=5)
    risk_level: RiskLevel = RiskLevel.LOW
    change_type: ChangeType = ChangeType.NORMAL
    implementation_plan: str = Field(..., min_length=5)
    test_plan: str = Field(..., min_length=5)
    rollback_plan: str = Field(..., min_length=5)
    problem_id: Optional[uuid.UUID] = None
    scheduled_start: Optional[datetime] = None
    scheduled_end: Optional[datetime] = None


class ChangeRequestUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = None
    description: Optional[str] = None
    reason: Optional[str] = None
    risk_level: Optional[RiskLevel] = None
    change_type: Optional[ChangeType] = None
    status: Optional[ChangeStatus] = None
    implementation_plan: Optional[str] = None
    test_plan: Optional[str] = None
    rollback_plan: Optional[str] = None
    scheduled_start: Optional[datetime] = None
    scheduled_end: Optional[datetime] = None


class CABDecisionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    approved: bool
    feedback: Optional[str] = None


class ChangeRequestOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    change_number: str
    title: str
    description: str
    reason: str
    risk_level: RiskLevel
    change_type: ChangeType
    status: ChangeStatus
    requester_id: uuid.UUID
    cab_approver_id: Optional[uuid.UUID] = None
    problem_id: Optional[uuid.UUID] = None
    implementation_plan: str
    test_plan: str
    rollback_plan: str
    scheduled_start: Optional[datetime] = None
    scheduled_end: Optional[datetime] = None
    cab_feedback: Optional[str] = None
    created_at: datetime
    updated_at: datetime


# ==========================================
# Major Incident Schemas
# ==========================================
class MajorIncidentTimelineCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    summary: str = Field(..., min_length=2, max_length=255)
    details: Optional[str] = None


class MajorIncidentTimelineOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    major_incident_id: uuid.UUID
    author_id: Optional[uuid.UUID] = None
    summary: str
    details: Optional[str] = None
    event_timestamp: datetime


class MajorIncidentCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    case_id: uuid.UUID
    title: str = Field(..., min_length=3, max_length=255)
    bridge_url: Optional[str] = None
    communications_lead_id: Optional[uuid.UUID] = None
    impact_summary: Optional[str] = None


class MajorIncidentUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = None
    status: Optional[MajorIncidentStatus] = None
    commander_id: Optional[uuid.UUID] = None
    bridge_url: Optional[str] = None
    communications_lead_id: Optional[uuid.UUID] = None
    executive_summary: Optional[str] = None
    impact_summary: Optional[str] = None
    post_mortem_url: Optional[str] = None


class MajorIncidentOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    incident_number: str
    case_id: uuid.UUID
    title: str
    status: MajorIncidentStatus
    commander_id: uuid.UUID
    bridge_url: Optional[str] = None
    communications_lead_id: Optional[uuid.UUID] = None
    executive_summary: Optional[str] = None
    impact_summary: Optional[str] = None
    declared_at: datetime
    mitigated_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    post_mortem_url: Optional[str] = None
    timeline_events: List[MajorIncidentTimelineOut] = []
