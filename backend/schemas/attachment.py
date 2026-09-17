import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class AttachmentOut(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)

    id: uuid.UUID
    case_id: uuid.UUID
    file_name: str
    storage_path: str
    file_type: str
    file_size: int
    uploaded_by: uuid.UUID
    uploader_email: Optional[str] = None
    created_at: datetime


class AttachmentDownloadOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    attachment_id: uuid.UUID
    file_name: str
    download_url: str
    expires_in_seconds: int


class CaseAttachmentQuotaOut(BaseModel):
    model_config = ConfigDict(extra="forbid")

    case_id: uuid.UUID
    used_bytes: int
    max_bytes: int
    remaining_bytes: int
    attachment_count: int
    used_percentage: float
