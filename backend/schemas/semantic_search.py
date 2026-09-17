from typing import List, Optional, Dict, Any
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

class SemanticSearchRequest(BaseModel):
    query: str = Field(..., min_length=2, max_length=500, description="Natural language search query")
    entity_types: Optional[List[str]] = Field(None, description="Filter by 'case', 'knowledge_article', etc.")
    limit: int = Field(10, ge=1, le=50)
    min_score: float = Field(0.3, ge=0.0, le=1.0)


class SemanticSearchResultItem(BaseModel):
    entity_type: str
    entity_id: UUID
    title: str
    content_snippet: str
    score: float
    metadata: Dict[str, Any] = Field(default_factory=dict)


class SemanticSearchResponse(BaseModel):
    query: str
    total_results: int
    results: List[SemanticSearchResultItem]


class NLQueryRequest(BaseModel):
    query: str = Field(..., min_length=3, max_length=500, description="Natural language question to synthesize")
    conversation_context: Optional[List[str]] = Field(None, description="Previous question/answer turns")


class CitationItem(BaseModel):
    entity_type: str
    entity_id: UUID
    title: str
    snippet: str


class NLQueryResponse(BaseModel):
    query: str
    answer: str
    citations: List[CitationItem] = Field(default_factory=list)
    confidence_score: float = 1.0


class NLQueryLogResponse(BaseModel):
    id: UUID
    query_text: str
    answer_text: str
    citations: List[CitationItem] = Field(default_factory=list)
    confidence_score: float
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class IndexEntityRequest(BaseModel):
    entity_type: str
    entity_id: UUID
    title: str
    content: str
    metadata: Optional[Dict[str, Any]] = None
