import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.user import User
from models.enums import UserRole, DraftStatus
from models.case import Case
from models.ai import AITriageResult, CaseSummary, CommunicationDraft
from schemas.ai import (
    AITriageResponse,
    ApplyTriageRequest,
    CaseSummaryResponse,
    CaseRiskAssessmentResponse,
    GenerateDraftRequest,
    SendDraftRequest,
    CommunicationDraftResponse,
)
from schemas.case import MessageOut, CaseOut
from services import ai_service

router = APIRouter(prefix="/cases/{case_id}", tags=["AI Operations"])

STAFF_ROLES = [
    UserRole.OPERATOR,
    UserRole.TEAM_LEAD,
    UserRole.MANAGER,
    UserRole.ADMINISTRATOR,
]


async def _verify_case_access(
    case_id: uuid.UUID,
    current_user: User,
    db: AsyncSession,
) -> Case:
    """Verify case existence and user authorization."""
    stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
    result = await db.execute(stmt)
    case = result.scalar_one_or_none()
    if not case:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "CASE_NOT_FOUND", "message": f"Case {case_id} not found."}},
        )

    if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "PERMISSION_DENIED", "message": "Access denied to this case."}},
        )

    return case


# --- 1. Case Triage (SRS §5.2) ---

@router.get("/triage", response_model=AITriageResponse)
async def get_case_triage(
    case_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Retrieve AI triage recommendations for an incident or service request."""
    await _verify_case_access(case_id, current_user, db)
    stmt = select(AITriageResult).where(AITriageResult.case_id == case_id)
    res = await db.execute(stmt)
    triage = res.scalar_one_or_none()
    if not triage:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "TRIAGE_NOT_FOUND", "message": "No triage record found for this case."}},
        )
    return triage


@router.post("/triage", response_model=AITriageResponse)
async def run_case_triage(
    case_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Trigger or re-evaluate AI triage on demand."""
    await _verify_case_access(case_id, current_user, db)
    triage = await ai_service.triage_case(db, case_id)
    if not triage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": {"code": "AI_UNAVAILABLE", "message": "AI Provider is currently unavailable."}},
        )
    return triage


@router.post("/triage/apply", response_model=CaseOut)
async def apply_case_triage(
    case_id: uuid.UUID,
    payload: ApplyTriageRequest,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Human-in-the-Loop: Operator explicitly accepts and applies AI recommendations (SRS §5.2).
    """
    await _verify_case_access(case_id, current_user, db)
    updated_case = await ai_service.apply_triage_recommendations(
        db=db,
        case_id=case_id,
        user_id=current_user.id,
        accept_category=payload.accept_category,
        accept_priority=payload.accept_priority,
        accept_team=payload.accept_team,
    )
    return updated_case


# --- 2. Living Case Summarization (SRS §5.3) ---

@router.get("/summary", response_model=CaseSummaryResponse)
async def get_case_summary(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Retrieve the continuous living case summary."""
    await _verify_case_access(case_id, current_user, db)
    stmt = select(CaseSummary).where(CaseSummary.case_id == case_id)
    res = await db.execute(stmt)
    summary = res.scalar_one_or_none()
    if not summary:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "SUMMARY_NOT_FOUND", "message": "No summary generated for this case yet."}},
        )
    return summary


@router.post("/summary/refresh", response_model=CaseSummaryResponse)
async def refresh_case_summary(
    case_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Force an immediate inline refresh of the living case summary."""
    await _verify_case_access(case_id, current_user, db)
    summary = await ai_service.summarize_case(db, case_id)
    if not summary:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": {"code": "AI_UNAVAILABLE", "message": "AI Provider is currently unavailable."}},
        )
    return summary


# --- 3. Risk Assessment (SRS §5.7) ---

@router.post("/risk", response_model=CaseRiskAssessmentResponse)
async def compute_case_risk(
    case_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Evaluate SLA risk and escalation signals."""
    await _verify_case_access(case_id, current_user, db)
    assessment = await ai_service.assess_case_risk(db, case_id)
    if not assessment:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": {"code": "AI_UNAVAILABLE", "message": "Risk assessment could not be completed."}},
        )
    return assessment


# --- 4. Communication Draft Assistant (SRS §5.9) ---

@router.post("/drafts", response_model=CommunicationDraftResponse, status_code=status.HTTP_201_CREATED)
async def generate_communication_draft(
    case_id: uuid.UUID,
    payload: GenerateDraftRequest,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Generate an AI draft communication for operator review."""
    await _verify_case_access(case_id, current_user, db)
    draft = await ai_service.generate_draft(
        db=db,
        case_id=case_id,
        draft_type=payload.draft_type,
        user_id=current_user.id,
        custom_instructions=payload.custom_instructions,
    )
    return draft


@router.get("/drafts", response_model=List[CommunicationDraftResponse])
async def list_communication_drafts(
    case_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """List all communication drafts for a case."""
    await _verify_case_access(case_id, current_user, db)
    stmt = (
        select(CommunicationDraft)
        .where(CommunicationDraft.case_id == case_id)
        .order_by(CommunicationDraft.created_at.desc())
    )
    res = await db.execute(stmt)
    return res.scalars().all()


@router.post("/drafts/{draft_id}/send", response_model=MessageOut)
async def send_communication_draft(
    case_id: uuid.UUID,
    draft_id: uuid.UUID,
    payload: SendDraftRequest,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Human-in-the-Loop: Operator explicitly reviews and sends draft.
    Creates a new message with ai_generated = True and updates case timeline.
    """
    await _verify_case_access(case_id, current_user, db)
    message = await ai_service.send_draft(
        db=db,
        draft_id=draft_id,
        user_id=current_user.id,
        final_body=payload.final_body,
    )
    return message


@router.delete("/drafts/{draft_id}", response_model=CommunicationDraftResponse)
async def discard_communication_draft(
    case_id: uuid.UUID,
    draft_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Discard an unwanted communication draft."""
    await _verify_case_access(case_id, current_user, db)
    return await ai_service.discard_draft(db, draft_id, current_user.id)
