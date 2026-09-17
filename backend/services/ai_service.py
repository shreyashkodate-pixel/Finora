import logging
from uuid import UUID
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from models.case import Case
from models.user import User, Team
from models.message import Message
from models.sla import SLA
from models.ai import AITriageResult, CaseSummary, CaseRiskAssessment, CommunicationDraft
from models.audit import AuditLog
from models.enums import (
    CasePriority,
    ConfidenceLevel,
    RiskLevel,
    DraftType,
    DraftStatus,
    MessageVisibility,
    UserRole,
)
from providers.ai import get_ai_provider, AIProvider, AIProviderUnavailableError
from services.case_service import SLA_DELTAS

logger = logging.getLogger("helpdesk.services.ai")


async def triage_case(
    db: AsyncSession,
    case_id: UUID,
    ai_provider: Optional[AIProvider] = None,
) -> Optional[AITriageResult]:
    """
    Run AI Triage analysis on a case per SRS §5.2.
    Surfaced as recommendations only; never auto-applied.
    """
    stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
    result = await db.execute(stmt)
    case = result.scalar_one_or_none()
    if not case:
        logger.warning(f"Triage aborted: Case {case_id} not found.")
        return None

    provider = ai_provider or get_ai_provider()

    try:
        triage_data = await provider.triage_case(
            title=case.title,
            description=case.description,
        )
    except AIProviderUnavailableError as exc:
        logger.warning(f"AI Provider unavailable during triage for case {case_id}: {exc}")
        return None
    except Exception as exc:
        logger.error(f"Unexpected error during triage for case {case_id}: {exc}")
        return None

    # 1. Resolve suggested team by name if possible
    suggested_team_id = None
    if triage_data.suggested_team_name:
        team_stmt = select(Team).where(func.lower(Team.name) == triage_data.suggested_team_name.lower())
        team_res = await db.execute(team_stmt)
        matched_team = team_res.scalar_one_or_none()
        if matched_team:
            suggested_team_id = matched_team.id

    # 2. Candidate related / duplicate cases per SRS §5.5 (same service or similar keywords)
    related_stmt = (
        select(Case.id, Case.reference_number, Case.title)
        .where(
            Case.id != case_id,
            Case.deleted_at.is_(None),
            or_(
                Case.service_id == case.service_id if case.service_id else False,
                Case.type == case.type,
            ),
        )
        .limit(3)
    )
    rel_res = await db.execute(related_stmt)
    related_cases = [
        {"id": str(r[0]), "reference_number": r[1], "title": r[2]}
        for r in rel_res.fetchall()
    ]

    # 3. Fetch existing triage result or create new
    existing_stmt = select(AITriageResult).where(AITriageResult.case_id == case_id)
    existing_res = await db.execute(existing_stmt)
    triage_record = existing_res.scalar_one_or_none()

    if not triage_record:
        triage_record = AITriageResult(
            case_id=case_id,
            suggested_category=triage_data.suggested_category,
            suggested_severity=triage_data.suggested_severity,
            suggested_priority=triage_data.suggested_priority,
            confidence_level=triage_data.confidence_level,
            confidence_score=triage_data.confidence_score,
            supporting_factors=triage_data.supporting_factors,
            missing_info=triage_data.missing_info,
            suggested_team_id=suggested_team_id,
            recommended_next_action=triage_data.recommended_next_action,
            related_case_ids=related_cases,
        )
        db.add(triage_record)
    else:
        triage_record.suggested_category = triage_data.suggested_category
        triage_record.suggested_severity = triage_data.suggested_severity
        triage_record.suggested_priority = triage_data.suggested_priority
        triage_record.confidence_level = triage_data.confidence_level
        triage_record.confidence_score = triage_data.confidence_score
        triage_record.supporting_factors = triage_data.supporting_factors
        triage_record.missing_info = triage_data.missing_info
        triage_record.suggested_team_id = suggested_team_id
        triage_record.recommended_next_action = triage_data.recommended_next_action
        triage_record.related_case_ids = related_cases

    # 4. Append-only AuditLog entry per SRS §5.11
    audit = AuditLog(
        actor_id=None,  # System AI
        action="ai_triage_generated",
        target_type="case",
        target_id=case_id,
        before_value=None,
        after_value={
            "suggested_category": triage_data.suggested_category,
            "suggested_priority": triage_data.suggested_priority.value if triage_data.suggested_priority else None,
            "confidence_level": triage_data.confidence_level.value,
        },
        created_at=datetime.now(timezone.utc) + timedelta(milliseconds=10),
    )
    db.add(audit)

    await db.commit()
    await db.refresh(triage_record)
    logger.info(f"AI Triage completed for case {case.reference_number}: Priority={triage_record.suggested_priority}")
    return triage_record


async def apply_triage_recommendations(
    db: AsyncSession,
    case_id: UUID,
    user_id: UUID,
    accept_category: bool = True,
    accept_priority: bool = True,
    accept_team: bool = False,
) -> Case:
    """
    Human-in-the-Loop: Operator explicitly accepts and applies triage recommendations (SRS §5.2).
    """
    case_stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
    case_res = await db.execute(case_stmt)
    case = case_res.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    triage_stmt = select(AITriageResult).where(AITriageResult.case_id == case_id)
    triage_res = await db.execute(triage_stmt)
    triage = triage_res.scalar_one_or_none()
    if not triage:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No AI triage recommendations exist for this case.",
        )

    before_state = {
        "priority": case.priority.value,
        "team_id": str(case.team_id) if case.team_id else None,
        "site": case.site,
    }

    applied_changes = {}

    if accept_priority and triage.suggested_priority:
        old_priority = case.priority
        case.priority = triage.suggested_priority
        applied_changes["priority"] = triage.suggested_priority.value

        # Recalculate SLA if priority changed per SRS §4.3
        sla_stmt = select(SLA).where(SLA.case_id == case_id)
        sla_res = await db.execute(sla_stmt)
        sla = sla_res.scalar_one_or_none()
        if sla and old_priority != triage.suggested_priority:
            created_at = case.created_at or datetime.now(timezone.utc)
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            deltas = SLA_DELTAS[triage.suggested_priority]
            sla.target_response_at = created_at + deltas["response"]
            sla.target_resolve_at = created_at + deltas["resolve"]

    if accept_team and triage.suggested_team_id:
        case.team_id = triage.suggested_team_id
        applied_changes["team_id"] = str(triage.suggested_team_id)

    case.version += 1

    # Audit log entry for human acceptance
    audit = AuditLog(
        actor_id=user_id,
        action="ai_triage_applied",
        target_type="case",
        target_id=case_id,
        before_value=before_state,
        after_value=applied_changes,
        created_at=datetime.now(timezone.utc),
    )
    db.add(audit)

    await db.commit()
    # Reload with SLA eager-loaded for CaseOut serialization
    reload_stmt = select(Case).options(selectinload(Case.sla)).where(Case.id == case_id)
    reload_res = await db.execute(reload_stmt)
    reloaded_case = reload_res.scalar_one()
    logger.info(f"Operator {user_id} applied AI triage recommendations to case {case.reference_number}: {applied_changes}")
    return reloaded_case


async def summarize_case(
    db: AsyncSession,
    case_id: UUID,
    new_message_id: Optional[UUID] = None,
    ai_provider: Optional[AIProvider] = None,
) -> Optional[CaseSummary]:
    """
    Synchronous-on-write living case summarization per SRS §5.3.
    Recomputed inline when messages are added or on operator refresh.
    """
    case_stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
    case_res = await db.execute(case_stmt)
    case = case_res.scalar_one_or_none()
    if not case:
        logger.warning(f"Summarize aborted: Case {case_id} not found.")
        return None

    # Fetch all messages ordered chronologically
    msg_stmt = (
        select(Message)
        .where(Message.case_id == case_id)
        .order_by(Message.created_at.asc())
    )
    msg_res = await db.execute(msg_stmt)
    all_messages = msg_res.scalars().all()

    # Format history and extract newest message
    history_lines = [f"Original Description: {case.description}"]
    new_message_text = ""

    for msg in all_messages:
        if new_message_id and msg.id == new_message_id:
            new_message_text = f"[{msg.visibility.value}] {msg.body}"
        else:
            history_lines.append(f"[{msg.visibility.value}] {msg.body}")

    if not new_message_text and all_messages:
        new_message_text = f"[{all_messages[-1].visibility.value}] {all_messages[-1].body}"
        history_lines = history_lines[:-1]

    history_text = "\n".join(history_lines)
    provider = ai_provider or get_ai_provider()

    try:
        summary_text = await provider.summarize_case(
            title=case.title,
            history_text=history_text,
            new_message_text=new_message_text,
        )
    except AIProviderUnavailableError as exc:
        logger.warning(f"AI Provider unavailable for summary of case {case_id}: {exc}")
        return None
    except Exception as exc:
        logger.error(f"Error during summarization of case {case_id}: {exc}")
        return None

    # Fetch existing summary or create new
    existing_stmt = select(CaseSummary).where(CaseSummary.case_id == case_id)
    existing_res = await db.execute(existing_stmt)
    summary_record = existing_res.scalar_one_or_none()

    if not summary_record:
        summary_record = CaseSummary(
            case_id=case_id,
            summary_text=summary_text,
            last_source_message_id=new_message_id,
        )
        db.add(summary_record)
    else:
        summary_record.summary_text = summary_text
        summary_record.last_source_message_id = new_message_id

    await db.commit()
    await db.refresh(summary_record)
    logger.info(f"Case summary updated for case {case.reference_number}")
    return summary_record


async def assess_case_risk(
    db: AsyncSession,
    case_id: UUID,
    ai_provider: Optional[AIProvider] = None,
) -> Optional[CaseRiskAssessment]:
    """
    Compute SLA and Escalation Risk score for a case per SRS §5.7.
    """
    case_stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
    case_res = await db.execute(case_stmt)
    case = case_res.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    # Fetch SLA target
    sla_stmt = select(SLA).where(SLA.case_id == case_id)
    sla_res = await db.execute(sla_stmt)
    sla = sla_res.scalar_one_or_none()

    now = datetime.now(timezone.utc)

    # Inactivity hours
    last_msg_stmt = (
        select(Message.created_at)
        .where(Message.case_id == case_id)
        .order_by(Message.created_at.desc())
        .limit(1)
    )
    last_msg_res = await db.execute(last_msg_stmt)
    last_msg_time = last_msg_res.scalar_one_or_none()

    reference_time = last_msg_time or case.created_at or now
    if reference_time.tzinfo is None:
        reference_time = reference_time.replace(tzinfo=timezone.utc)
    inactivity_hours = max(0.0, (now - reference_time).total_seconds() / 3600.0)

    # Hours to SLA deadline
    hours_to_deadline = 24.0
    if sla and sla.target_resolve_at:
        res_deadline = sla.target_resolve_at
        if res_deadline.tzinfo is None:
            res_deadline = res_deadline.replace(tzinfo=timezone.utc)
        hours_to_deadline = (res_deadline - now).total_seconds() / 3600.0

    # Count requester messages
    req_msg_stmt = (
        select(func.count(Message.id))
        .where(Message.case_id == case_id, Message.author_id == case.requester_id)
    )
    req_res = await db.execute(req_msg_stmt)
    follow_up_count = req_res.scalar_one() or 0

    context = {
        "title": case.title,
        "priority": case.priority.value,
        "inactivity_hours": round(inactivity_hours, 1),
        "hours_to_deadline": round(hours_to_deadline, 1),
        "follow_up_count": follow_up_count,
        "reopen_count": 0,  # can be tracked from audit logs or case
    }

    provider = ai_provider or get_ai_provider()
    try:
        risk_data = await provider.assess_risk(case_context=context)
    except AIProviderUnavailableError as exc:
        logger.warning(f"AI Provider unavailable for risk evaluation on case {case_id}: {exc}")
        return None

    assessment = CaseRiskAssessment(
        case_id=case_id,
        risk_level=risk_data.risk_level,
        signals={
            **risk_data.signals,
            "risk_score": risk_data.risk_score,
            "rationale": risk_data.rationale,
        },
    )
    db.add(assessment)
    await db.commit()
    await db.refresh(assessment)
    logger.info(f"Risk assessment computed for case {case.reference_number}: Level={assessment.risk_level}")
    return assessment


async def generate_draft(
    db: AsyncSession,
    case_id: UUID,
    draft_type: DraftType,
    user_id: UUID,
    custom_instructions: Optional[str] = None,
    ai_provider: Optional[AIProvider] = None,
) -> CommunicationDraft:
    """
    Generate AI Communication Draft per SRS §5.9.
    Surfaced to operator for review and editing; never auto-sent.
    """
    case_stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
    case_res = await db.execute(case_stmt)
    case = case_res.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    # Fetch requester
    req_stmt = select(User).where(User.id == case.requester_id)
    req_res = await db.execute(req_stmt)
    requester = req_res.scalar_one_or_none()
    requester_name = requester.email.split("@")[0] if requester and requester.email else "Valued Colleague"

    context = {
        "title": case.title,
        "requester_name": requester_name,
        "status": case.status.value,
        "category": case.service_id or "General IT",
    }

    provider = ai_provider or get_ai_provider()
    try:
        draft_data = await provider.draft_communication(
            draft_type=draft_type,
            case_context=context,
            custom_instructions=custom_instructions,
        )
    except AIProviderUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AI Provider unavailable for drafting: {exc}",
        )

    draft = CommunicationDraft(
        case_id=case_id,
        draft_type=draft_type,
        body=draft_data.body,
        status=DraftStatus.DRAFT,
        reviewed_by=user_id,
    )
    db.add(draft)
    await db.commit()
    await db.refresh(draft)
    logger.info(f"Generated {draft_type.value} draft {draft.id} for case {case.reference_number}")
    return draft


async def send_draft(
    db: AsyncSession,
    draft_id: UUID,
    user_id: UUID,
    final_body: Optional[str] = None,
) -> Message:
    """
    Human-in-the-Loop: Operator explicitly reviews and sends draft communication (SRS §5.9).
    Persists a Message with ai_generated = True and refreshes living summary.
    """
    draft_stmt = select(CommunicationDraft).where(CommunicationDraft.id == draft_id)
    draft_res = await db.execute(draft_stmt)
    draft = draft_res.scalar_one_or_none()
    if not draft:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Draft not found")

    if draft.status != DraftStatus.DRAFT:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot send draft with status '{draft.status.value}'",
        )

    case_stmt = select(Case).where(Case.id == draft.case_id, Case.deleted_at.is_(None))
    case_res = await db.execute(case_stmt)
    case = case_res.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

    body_to_send = final_body.strip() if final_body and final_body.strip() else draft.body

    # Create message with ai_generated=True visibly tagged
    message = Message(
        case_id=draft.case_id,
        author_id=user_id,
        body=body_to_send,
        visibility=MessageVisibility.REQUESTER_VISIBLE,
        ai_generated=True,
    )
    db.add(message)
    await db.flush()

    draft.status = DraftStatus.SENT
    draft.sent_message_id = message.id
    draft.reviewed_by = user_id

    # Append audit log
    audit = AuditLog(
        actor_id=user_id,
        action="ai_draft_sent",
        target_type="case",
        target_id=draft.case_id,
        before_value={"draft_id": str(draft.id), "status": "draft"},
        after_value={"message_id": str(message.id), "status": "sent", "ai_generated": True},
    )
    db.add(audit)

    await db.commit()
    await db.refresh(message)

    # Recompute living summary inline
    await summarize_case(db, case_id=draft.case_id, new_message_id=message.id)

    logger.info(f"Operator {user_id} sent AI draft {draft_id} as message {message.id} on case {case.reference_number}")
    return message


async def discard_draft(
    db: AsyncSession,
    draft_id: UUID,
    user_id: UUID,
) -> CommunicationDraft:
    """Discard an unwanted AI communication draft."""
    draft_stmt = select(CommunicationDraft).where(CommunicationDraft.id == draft_id)
    draft_res = await db.execute(draft_stmt)
    draft = draft_res.scalar_one_or_none()
    if not draft:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Draft not found")

    draft.status = DraftStatus.DISCARDED
    draft.reviewed_by = user_id
    await db.commit()
    await db.refresh(draft)
    logger.info(f"Operator {user_id} discarded AI draft {draft_id}")
    return draft
