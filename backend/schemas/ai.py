from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field

from models.enums import CasePriority, ConfidenceLevel, RiskLevel, DraftType, DraftStatus


class AITriageResponse(BaseModel):
    id: UUID
    case_id: UUID
    suggested_category: Optional[str] = None
    suggested_severity: Optional[str] = None
    suggested_priority: Optional[CasePriority] = None
    confidence_level: ConfidenceLevel
    supporting_factors: Optional[Any] = None
    missing_info: Optional[Any] = None
    suggested_team_id: Optional[UUID] = None
    suggested_team_name: Optional[str] = None
    recommended_next_action: Optional[str] = None
    related_case_ids: Optional[Any] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ApplyTriageRequest(BaseModel):
    accept_category: bool = Field(default=True, description="Accept AI suggested category")
    accept_priority: bool = Field(default=True, description="Accept AI suggested priority")
    accept_team: bool = Field(default=False, description="Accept AI suggested team assignment")


class CaseSummaryResponse(BaseModel):
    id: UUID
    case_id: UUID
    summary_text: str
    last_source_message_id: Optional[UUID] = None
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CaseRiskAssessmentResponse(BaseModel):
    id: UUID
    case_id: UUID
    risk_level: RiskLevel
    signals: Dict[str, Any]
    computed_at: datetime

    model_config = ConfigDict(from_attributes=True)


class GenerateDraftRequest(BaseModel):
    draft_type: DraftType = Field(description="info_request | progress_update | resolution | escalation_summary")
    custom_instructions: Optional[str] = Field(default=None, max_length=1000, description="Optional custom guidelines")


class SendDraftRequest(BaseModel):
    final_body: Optional[str] = Field(default=None, description="Optional edited body text overriding initial draft")


class CommunicationDraftResponse(BaseModel):
    id: UUID
    case_id: UUID
    draft_type: DraftType
    body: str
    status: DraftStatus
    reviewed_by: Optional[UUID] = None
    sent_message_id: Optional[UUID] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
