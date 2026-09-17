from typing import Optional, Dict
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class DeviceTokenRegisterRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=500, description="FCM / APNs device token string")
    platform: str = Field("android", description="Device OS: android, ios, web")
    device_name: Optional[str] = Field(None, max_length=100)


class DeviceTokenResponse(BaseModel):
    id: UUID
    user_id: UUID
    token: str
    platform: str
    device_name: Optional[str] = None
    is_active: bool
    created_at: datetime
    last_seen_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SendPushTestRequest(BaseModel):
    title: str = Field("Test Notification", min_length=1, max_length=150)
    body: str = Field("This is a test notification from Finora AI IT Helpdesk.", min_length=1, max_length=500)
    data: Optional[Dict[str, str]] = None


class SendPushResponse(BaseModel):
    sent_count: int
    failed_count: int
    status: str
