import math
import hashlib
from typing import List, Dict, Any, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from models.semantic_search import SemanticEmbedding, NLQueryLog
from models.user import User
from models.enums import UserRole
from schemas.semantic_search import (
    SemanticSearchResultItem,
    SemanticSearchResponse,
    CitationItem,
    NLQueryResponse,
)


def _generate_embedding(text: str, dim: int = 128) -> List[float]:
    """
    Generates a deterministic normalized pseudo-semantic embedding vector for text.
    Ensures consistent vector similarity calculation without requiring heavy external models.
    """
    cleaned = text.lower().strip()
    words = cleaned.split()
    vector = [0.0] * dim
    
    for i, word in enumerate(words):
        h = int(hashlib.md5(word.encode("utf-8")).hexdigest(), 16)
        idx = h % dim
        weight = 1.0 / (1.0 + 0.1 * i)
        vector[idx] += weight
        # Bigram distribution
        if i > 0:
            bi = f"{words[i-1]}_{word}"
            h_bi = int(hashlib.sha256(bi.encode("utf-8")).hexdigest(), 16)
            vector[h_bi % dim] += 1.5

    # L2 Normalization
    norm = math.sqrt(sum(x * x for x in vector))
    if norm > 0:
        vector = [x / norm for x in vector]
    else:
        vector[0] = 1.0
    return vector


def _cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """Computes cosine similarity between two normalized vectors."""
    dot = sum(a * b for a, b in zip(vec1, vec2))
    return max(0.0, min(1.0, dot))


class SemanticSearchService:
    @staticmethod
    async def index_entity(
        db: AsyncSession,
        entity_type: str,
        entity_id: UUID,
        title: str,
        content: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> SemanticEmbedding:
        """Indexes or updates an entity's vector embedding in the database."""
        stmt = select(SemanticEmbedding).where(
            SemanticEmbedding.entity_type == entity_type,
            SemanticEmbedding.entity_id == entity_id,
        )
        res = await db.execute(stmt)
        existing = res.scalars().first()

        combined_text = f"{title}\n{content}"
        embedding_vector = _generate_embedding(combined_text)

        if existing:
            existing.title = title
            existing.content_chunk = content[:4000]
            existing.embedding = embedding_vector
            existing.metadata_json = metadata or {}
            await db.commit()
            await db.refresh(existing)
            return existing
        else:
            new_emb = SemanticEmbedding(
                entity_type=entity_type,
                entity_id=entity_id,
                title=title,
                content_chunk=content[:4000],
                embedding=embedding_vector,
                metadata_json=metadata or {},
            )
            db.add(new_emb)
            await db.commit()
            await db.refresh(new_emb)
            return new_emb

    @staticmethod
    async def search(
        db: AsyncSession,
        query: str,
        current_user: User,
        entity_types: Optional[List[str]] = None,
        limit: int = 10,
        min_score: float = 0.2,
    ) -> SemanticSearchResponse:
        """
        Performs semantic vector search with strict RBAC permission filtering.
        """
        query_vec = _generate_embedding(query)

        stmt = select(SemanticEmbedding)
        if entity_types:
            stmt = stmt.where(SemanticEmbedding.entity_type.in_(entity_types))

        res = await db.execute(stmt)
        all_embeddings = res.scalars().all()

        results = []
        is_staff = current_user.role in (
            UserRole.OPERATOR,
            UserRole.TEAM_LEAD,
            UserRole.MANAGER,
            UserRole.ADMINISTRATOR,
        )

        for item in all_embeddings:
            meta = item.metadata_json or {}

            # Strict RBAC filtering for Requesters
            if not is_staff:
                if item.entity_type == "case":
                    if meta.get("requester_id") != str(current_user.id):
                        continue
                elif item.entity_type == "knowledge_article":
                    if meta.get("state") != "published":
                        continue

            score = _cosine_similarity(query_vec, item.embedding)
            if score >= min_score:
                snippet = item.content_chunk[:200] + ("..." if len(item.content_chunk) > 200 else "")
                results.append(
                    SemanticSearchResultItem(
                        entity_type=item.entity_type,
                        entity_id=item.entity_id,
                        title=item.title,
                        content_snippet=snippet,
                        score=round(score, 4),
                        metadata=meta,
                    )
                )

        results.sort(key=lambda x: x.score, reverse=True)
        top_results = results[:limit]

        return SemanticSearchResponse(
            query=query,
            total_results=len(top_results),
            results=top_results,
        )

    @staticmethod
    async def nl_query(
        db: AsyncSession,
        query: str,
        current_user: User,
        conversation_context: Optional[List[str]] = None,
    ) -> NLQueryResponse:
        """
        Synthesizes a natural language answer with source citations based on semantic discovery context.
        """
        search_res = await SemanticSearchService.search(
            db=db,
            query=query,
            current_user=current_user,
            limit=4,
            min_score=0.1,
        )

        citations: List[CitationItem] = []
        context_snippets = []

        for r in search_res.results:
            citations.append(
                CitationItem(
                    entity_type=r.entity_type,
                    entity_id=r.entity_id,
                    title=r.title,
                    snippet=r.content_snippet,
                )
            )
            context_snippets.append(f"[{r.entity_type.upper()}] {r.title}: {r.content_snippet}")

        if context_snippets:
            answer = (
                f"Based on our IT knowledge records:\n\n"
                + "\n\n".join(f"• {c}" for c in context_snippets)
                + f"\n\nRegarding your query '{query}', please follow the documented steps above or reach out to IT support."
            )
            confidence = 0.95
        else:
            answer = (
                f"No specific matching knowledge articles or previous cases were found for '{query}'. "
                "Please raise a new IT ticket or check system status."
            )
            confidence = 0.50

        # Save query log
        log_entry = NLQueryLog(
            user_id=current_user.id,
            query_text=query,
            answer_text=answer,
            citations=[c.model_dump() for c in citations],
            confidence_score=confidence,
        )
        db.add(log_entry)
        await db.commit()

        return NLQueryResponse(
            query=query,
            answer=answer,
            citations=citations,
            confidence_score=confidence,
        )

    @staticmethod
    async def get_query_history(
        db: AsyncSession,
        current_user: User,
        limit: int = 20,
    ) -> List[NLQueryLog]:
        stmt = (
            select(NLQueryLog)
            .where(NLQueryLog.user_id == current_user.id)
            .order_by(desc(NLQueryLog.created_at))
            .limit(limit)
        )
        res = await db.execute(stmt)
        return list(res.scalars().all())
