from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db_session
from models.user import User
from models.enums import UserRole
from api.deps import get_current_active_user, require_roles
from schemas.semantic_search import (
    SemanticSearchRequest,
    SemanticSearchResponse,
    NLQueryRequest,
    NLQueryResponse,
    NLQueryLogResponse,
    IndexEntityRequest,
)
from services.semantic_search_service import SemanticSearchService

router = APIRouter(prefix="/search", tags=["Semantic Search & NL Discovery"])


@router.post("/semantic", response_model=SemanticSearchResponse, status_code=status.HTTP_200_OK)
async def semantic_search(
    payload: SemanticSearchRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Performs semantic vector search across knowledge articles, cases, and SOPs with role-based filtering.
    """
    return await SemanticSearchService.search(
        db=db,
        query=payload.query,
        current_user=current_user,
        entity_types=payload.entity_types,
        limit=payload.limit,
        min_score=payload.min_score,
    )


@router.post("/nl-query", response_model=NLQueryResponse, status_code=status.HTTP_200_OK)
async def natural_language_query(
    payload: NLQueryRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Synthesizes a contextual natural language answer with citations based on permission-aware semantic discovery.
    """
    return await SemanticSearchService.nl_query(
        db=db,
        query=payload.query,
        current_user=current_user,
        conversation_context=payload.conversation_context,
    )


@router.get("/history", response_model=List[NLQueryLogResponse], status_code=status.HTTP_200_OK)
async def get_nl_query_history(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Retrieves the calling user's historical natural language questions and answers.
    """
    return await SemanticSearchService.get_query_history(
        db=db,
        current_user=current_user,
    )


@router.post("/index", status_code=status.HTTP_201_CREATED)
async def index_entity_embedding(
    payload: IndexEntityRequest,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Indexes an entity text into vector embeddings for semantic discovery.
    """
    embedding = await SemanticSearchService.index_entity(
        db=db,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        title=payload.title,
        content=payload.content,
        metadata=payload.metadata,
    )
    return {
        "status": "indexed",
        "entity_type": embedding.entity_type,
        "entity_id": str(embedding.entity_id),
    }
