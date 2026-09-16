import uuid
from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, ConfigDict, Field

from models.enums import CaseType, CaseStatus, CasePriority, RelationshipType, MessageVisibility


class SLAOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    target_response_at: datetime
    target_resolve_at: datetime
    responded_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    response_breached: bool = False
    resolution_breached: bool = False
    paused_reason: Optional[str] = None


class MessageCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    body: str = Field(..., min_length=1, max_length=10000)
    visibility: MessageVisibility = MessageVisibility.REQUESTER_VISIBLE


class MessageOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    case_id: uuid.UUID
    author_id: uuid.UUID
    author_email: Optional[str] = None
    body: str
    visibility: MessageVisibility
    ai_generated: bool = False
    created_at: datetime


class CaseRelationshipCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    related_case_id: uuid.UUID
    relationship_type: RelationshipType


class CaseRelationshipOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    case_id: uuid.UUID
    related_case_id: uuid.UUID
    relationship_type: RelationshipType
    created_at: datetime


class AuditLogOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    actor_id: Optional[uuid.UUID] = None
    action: str
    target_type: str
    target_id: uuid.UUID
    before_value: Optional[Any] = None
    after_value: Optional[Any] = None
    created_at: datetime


class CaseCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(..., min_length=1, max_length=10000)
    type: CaseType = CaseType.INCIDENT
    priority: CasePriority = CasePriority.P3
    site: Optional[str] = Field(None, max_length=100)
    service_id: Optional[str] = Field(None, max_length=100)


class CaseUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Optional[str] = Field(None, min_length=1, max_length=200)
    priority: Optional[CasePriority] = None
    owner_id: Optional[uuid.UUID] = None
    team_id: Optional[uuid.UUID] = None
    service_id: Optional[str] = Field(None, max_length=100)
    # Optimistic locking integer per SRS §7.12
    version: int = Field(..., ge=1)


class CaseStatusTransition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    new_status: CaseStatus
    reason: Optional[str] = Field(None, max_length=1000)
    # Optimistic locking integer per SRS §7.12
    version: int = Field(..., ge=1)


class CaseOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    reference_number: str
    type: CaseType
    title: str
    description: str
    status: CaseStatus
    priority: CasePriority
    requester_id: uuid.UUID
    owner_id: Optional[uuid.UUID] = None
    team_id: Optional[uuid.UUID] = None
    site: Optional[str] = None
    service_id: Optional[str] = None
    version: int
    created_at: datetime
    resolved_at: Optional[datetime] = None
    closed_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None
    sla: Optional[SLAOut] = None


class CaseListOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: List[CaseOut]
    total: int
    page: int
    per_page: int
