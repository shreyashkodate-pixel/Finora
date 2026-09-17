import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from models.enums import AutoFixActionType, AutoFixStatus


class AutoFixProposeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    action_type: AutoFixActionType
    parameters: Dict[str, Any] = Field(default_factory=dict)


class AutoFixExecuteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    dry_run: bool = False
    confirmed: bool = True


class AutoFixActionOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    case_id: uuid.UUID
    action_type: AutoFixActionType
    parameters: Dict[str, Any]
    status: AutoFixStatus
    initiated_by: Optional[uuid.UUID] = None
    execution_output: Optional[str] = None
    rollback_output: Optional[str] = None
    error_message: Optional[str] = None
    executed_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
