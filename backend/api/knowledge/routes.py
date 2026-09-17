import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.enums import KnowledgeState, UserRole
from models.user import User
from schemas.knowledge import (
    KnowledgeArticleCreate,
    KnowledgeArticleUpdate,
    KnowledgeArticleOut,
    KnowledgeArticleListOut,
)
from services.knowledge_service import KnowledgeService

router = APIRouter(prefix="/knowledge", tags=["Knowledge Base"])


@router.post(
    "",
    response_model=KnowledgeArticleOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create knowledge article (Staff only)",
)
async def create_article(
    payload: KnowledgeArticleCreate,
    current_user: User = Depends(
        require_roles([
            UserRole.OPERATOR,
            UserRole.TEAM_LEAD,
            UserRole.MANAGER,
            UserRole.ADMINISTRATOR,
        ])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = KnowledgeService(db)
    return await service.create_article(payload, current_user)


@router.get(
    "",
    response_model=KnowledgeArticleListOut,
    summary="List and search knowledge articles",
)
async def list_articles(
    state: Optional[KnowledgeState] = Query(None, description="Filter by state (staff only)"),
    search: Optional[str] = Query(None, description="Search across title and body"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = KnowledgeService(db)
    items, total = await service.list_articles(
        current_user=current_user,
        state=state,
        search_query=search,
        limit=limit,
        offset=offset,
    )
    return KnowledgeArticleListOut(items=items, total=total)


@router.get(
    "/{article_id}",
    response_model=KnowledgeArticleOut,
    summary="Get knowledge article by ID",
)
async def get_article(
    article_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = KnowledgeService(db)
    return await service.get_article(article_id, current_user)


@router.put(
    "/{article_id}",
    response_model=KnowledgeArticleOut,
    summary="Update knowledge article (Owner or Manager)",
)
async def update_article(
    article_id: uuid.UUID,
    payload: KnowledgeArticleUpdate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = KnowledgeService(db)
    return await service.update_article(article_id, payload, current_user)


@router.post(
    "/{article_id}/archive",
    response_model=KnowledgeArticleOut,
    summary="Archive knowledge article",
)
async def archive_article(
    article_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = KnowledgeService(db)
    return await service.archive_article(article_id, current_user)


@router.get(
    "/suggestions/case/{case_id}",
    response_model=List[KnowledgeArticleOut],
    summary="Contextual knowledge article suggestions for a case",
)
async def suggest_articles_for_case(
    case_id: uuid.UUID,
    limit: int = Query(5, ge=1, le=10),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = KnowledgeService(db)
    return await service.suggest_articles_for_case(case_id, current_user, limit=limit)
