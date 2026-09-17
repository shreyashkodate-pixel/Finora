import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict

from models.enums import NotificationEventType


class NotificationOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    case_id: Optional[uuid.UUID] = None
    title: str
    message: str
    event_type: NotificationEventType
    is_read: bool
    created_at: datetime


class NotificationListOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: List[NotificationOut]
    total: int
    unread_count: int
    page: int
    per_page: int


class UnreadCountOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    unread_count: int
