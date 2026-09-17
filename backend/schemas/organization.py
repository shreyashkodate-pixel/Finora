from typing import List, Optional
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class TenantPolicyUpdate(BaseModel):
    data_retention_days: Optional[int] = Field(None, ge=30, le=3650)
    require_mfa: Optional[bool] = None
    allow_password_auth: Optional[bool] = None
    allow_google_oauth: Optional[bool] = None
    ai_auto_triage_enabled: Optional[bool] = None
    ai_autofix_enabled: Optional[bool] = None


class TenantPolicyResponse(BaseModel):
    id: UUID
    organization_id: UUID
    data_retention_days: int
    require_mfa: bool
    allow_password_auth: bool
    allow_google_oauth: bool
    ai_auto_triage_enabled: bool
    ai_autofix_enabled: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class OrganizationCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    slug: str = Field(..., min_length=2, max_length=80)
    domain_whitelist: List[str] = Field(default_factory=list)
    sla_tier: str = Field("enterprise", max_length=50)
    max_users: int = Field(500, ge=1, le=100000)


class OrganizationResponse(BaseModel):
    id: UUID
    name: str
    slug: str
    domain_whitelist: List[str] = Field(default_factory=list)
    sla_tier: str
    max_users: int
    is_active: bool
    created_at: datetime
    policy: Optional[TenantPolicyResponse] = None

    model_config = ConfigDict(from_attributes=True)


class OrganizationStatsResponse(BaseModel):
    organization_id: UUID
    name: str
    slug: str
    total_users: int
    total_teams: int
    total_cases: int
    is_active: bool
