from datetime import datetime
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field

from models.enums import KnowledgeState


class KnowledgeArticleCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=255, description="Article title")
    body: str = Field(..., min_length=10, description="Markdown body of the article")
    state: Optional[KnowledgeState] = Field(
        default=KnowledgeState.DRAFT,
        description="Initial lifecycle state (draft or published)",
    )
    review_date: Optional[datetime] = Field(
        default=None,
        description="Scheduled periodic review date per SRS §4",
    )
    source_case_id: Optional[UUID] = Field(
        default=None,
        description="Optional resolved case this article was originated from",
    )


class KnowledgeArticleUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=3, max_length=255)
    body: Optional[str] = Field(default=None, min_length=10)
    state: Optional[KnowledgeState] = None
    review_date: Optional[datetime] = None


class KnowledgeArticleOut(BaseModel):
    id: UUID
    title: str
    body: str
    owner_id: UUID
    state: KnowledgeState
    review_date: Optional[datetime] = None
    source_case_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class KnowledgeArticleListOut(BaseModel):
    items: List[KnowledgeArticleOut]
    total: int


class KnowledgeSuggestionOut(BaseModel):
    article: KnowledgeArticleOut
    relevance_score: Optional[float] = None
