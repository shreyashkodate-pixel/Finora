import re
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from models.audit import AuditLog
from models.case import Case
from models.enums import KnowledgeState, UserRole
from models.knowledge import KnowledgeArticle
from models.user import User
from schemas.knowledge import KnowledgeArticleCreate, KnowledgeArticleUpdate


class KnowledgeService:
    """
    Manages Knowledge Base article authoring, state lifecycle, search,
    and contextual article recommendations per SRS §4, §5.14 & §7.6.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_article(
        self, payload: KnowledgeArticleCreate, current_user: User
    ) -> KnowledgeArticle:
        """
        Author a new knowledge article.
        Requesters cannot author articles (SRS §7.6: only authorized staff).
        """
        if current_user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters cannot author knowledge articles.",
                        "details": {},
                    }
                },
            )

        # Validate source case if provided
        if payload.source_case_id:
            case_stmt = select(Case).where(Case.id == payload.source_case_id)
            case_result = await self.db.execute(case_stmt)
            if not case_result.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail={
                        "error": {
                            "code": "CASE_NOT_FOUND",
                            "message": f"Source case {payload.source_case_id} does not exist.",
                            "details": {},
                        }
                    },
                )

        now = datetime.now(timezone.utc)
        article_id = uuid.uuid4()
        article = KnowledgeArticle(
            id=article_id,
            title=payload.title,
            body=payload.body,
            owner_id=current_user.id,
            state=payload.state or KnowledgeState.DRAFT,
            review_date=payload.review_date,
            source_case_id=payload.source_case_id,
            created_at=now,
            updated_at=now,
        )
        self.db.add(article)

        # Audit log creation
        audit = AuditLog(
            actor_id=current_user.id,
            action="KNOWLEDGE_ARTICLE_CREATED",
            target_type="KnowledgeArticle",
            target_id=article.id,
            before_value=None,
            after_value={
                "title": article.title,
                "state": article.state.value,
                "source_case_id": str(article.source_case_id) if article.source_case_id else None,
            },
            created_at=now,
        )
        self.db.add(audit)

        await self.db.commit()
        await self.db.refresh(article)
        return article

    async def get_article(self, article_id: uuid.UUID, current_user: User) -> KnowledgeArticle:
        """
        Retrieve article by ID.
        Requesters can only access PUBLISHED articles (SRS §7.6).
        """
        stmt = select(KnowledgeArticle).where(KnowledgeArticle.id == article_id)
        result = await self.db.execute(stmt)
        article = result.scalar_one_or_none()

        if not article:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "KNOWLEDGE_NOT_FOUND",
                        "message": "Knowledge article not found.",
                        "details": {"article_id": str(article_id)},
                    }
                },
            )

        if current_user.role == UserRole.REQUESTER and article.state != KnowledgeState.PUBLISHED:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters may only view published knowledge articles.",
                        "details": {},
                    }
                },
            )

        return article

    async def list_articles(
        self,
        current_user: User,
        state: Optional[KnowledgeState] = None,
        search_query: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[KnowledgeArticle], int]:
        """
        List and search articles with pagination.
        Requesters are restricted to published articles only.
        """
        query = select(KnowledgeArticle)

        if current_user.role == UserRole.REQUESTER:
            query = query.where(KnowledgeArticle.state == KnowledgeState.PUBLISHED)
        elif state is not None:
            query = query.where(KnowledgeArticle.state == state)

        if search_query and search_query.strip():
            clean_q = f"%{search_query.strip()}%"
            query = query.where(
                or_(
                    KnowledgeArticle.title.ilike(clean_q),
                    KnowledgeArticle.body.ilike(clean_q),
                )
            )

        # Count total
        count_query = select(func.count()).select_from(query.subquery())
        total_result = await self.db.execute(count_query)
        total = total_result.scalar() or 0

        # Execute paginated query
        paginated_query = (
            query.order_by(KnowledgeArticle.created_at.desc())
            .offset(offset)
            .limit(min(limit, 100))
        )
        result = await self.db.execute(paginated_query)
        articles = list(result.scalars().all())

        return articles, total

    async def update_article(
        self,
        article_id: uuid.UUID,
        payload: KnowledgeArticleUpdate,
        current_user: User,
    ) -> KnowledgeArticle:
        """
        Update an article's content or state.
        Permitted only for owner or staff with elevated authority (Lead, Manager, Admin).
        """
        article = await self.get_article(article_id, current_user)

        # Check update authorization
        elevated_roles = {UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR}
        if article.owner_id != current_user.id and current_user.role not in elevated_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Only the article author or a Team Lead/Manager/Administrator can update this article.",
                        "details": {},
                    }
                },
            )

        before_state = {
            "title": article.title,
            "state": article.state.value,
        }

        if payload.title is not None:
            article.title = payload.title
        if payload.body is not None:
            article.body = payload.body
        if payload.state is not None:
            article.state = payload.state
        if payload.review_date is not None:
            article.review_date = payload.review_date

        now = datetime.now(timezone.utc)
        article.updated_at = now

        audit = AuditLog(
            actor_id=current_user.id,
            action="KNOWLEDGE_ARTICLE_UPDATED",
            target_type="KnowledgeArticle",
            target_id=article.id,
            before_value=before_state,
            after_value={
                "title": article.title,
                "state": article.state.value,
            },
            created_at=now,
        )
        self.db.add(audit)

        await self.db.commit()
        await self.db.refresh(article)
        return article

    async def archive_article(
        self, article_id: uuid.UUID, current_user: User
    ) -> KnowledgeArticle:
        """
        Transition an article to ARCHIVED state.
        Permitted for author, Lead, Manager, or Admin.
        """
        article = await self.get_article(article_id, current_user)

        elevated_roles = {UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR}
        if article.owner_id != current_user.id and current_user.role not in elevated_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Only the article author or an elevated manager can archive this article.",
                        "details": {},
                    }
                },
            )

        now = datetime.now(timezone.utc)
        article.state = KnowledgeState.ARCHIVED
        article.updated_at = now

        audit = AuditLog(
            actor_id=current_user.id,
            action="KNOWLEDGE_ARTICLE_ARCHIVED",
            target_type="KnowledgeArticle",
            target_id=article.id,
            before_value={"state": article.state.value},
            after_value={"state": KnowledgeState.ARCHIVED.value},
            created_at=now,
        )
        self.db.add(audit)

        await self.db.commit()
        await self.db.refresh(article)
        return article

    async def suggest_articles_for_case(
        self, case_id: uuid.UUID, current_user: User, limit: int = 5
    ) -> List[KnowledgeArticle]:
        """
        Contextual knowledge article suggestions for a case per SRS §5.14.
        Extracts key tokens from the case title and description and matches
        against published knowledge articles.
        """
        case_stmt = select(Case).where(Case.id == case_id)
        case_result = await self.db.execute(case_stmt)
        case = case_result.scalar_one_or_none()

        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "CASE_NOT_FOUND",
                        "message": f"Case {case_id} not found.",
                        "details": {},
                    }
                },
            )

        # Check visibility
        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "You do not have permission to view suggestions for this case.",
                        "details": {},
                    }
                },
            )

        # Extract tokens from case title and description
        text_source = f"{case.title} {case.description or ''}"
        raw_tokens = re.findall(r"\b[A-Za-z0-9_]{3,}\b", text_source)

        stop_words = {
            "the", "and", "for", "with", "this", "that", "from", "have", "been",
            "every", "some", "what", "when", "where", "case", "issue", "problem",
            "help", "need", "please", "user", "error", "client", "does", "cannot",
        }
        tokens = [t.lower() for t in raw_tokens if t.lower() not in stop_words][:8]

        # Search published articles matching tokens
        if tokens:
            conditions = []
            for token in tokens:
                pattern = f"%{token}%"
                conditions.append(KnowledgeArticle.title.ilike(pattern))
                conditions.append(KnowledgeArticle.body.ilike(pattern))

            query = (
                select(KnowledgeArticle)
                .where(
                    KnowledgeArticle.state == KnowledgeState.PUBLISHED,
                    or_(*conditions),
                )
                .order_by(KnowledgeArticle.created_at.desc())
                .limit(limit)
            )
            result = await self.db.execute(query)
            articles = list(result.scalars().all())
            if articles:
                return articles

        # Fallback: return most recent published articles
        fallback_query = (
            select(KnowledgeArticle)
            .where(KnowledgeArticle.state == KnowledgeState.PUBLISHED)
            .order_by(KnowledgeArticle.created_at.desc())
            .limit(limit)
        )
        fallback_result = await self.db.execute(fallback_query)
        return list(fallback_result.scalars().all())
