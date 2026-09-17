import uuid
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from models.audit import AuditLog
from models.case import Case
from models.enums import (
    ProblemStatus,
    CasePriority,
    ChangeType,
    ChangeStatus,
    MajorIncidentStatus,
    UserRole,
    MessageVisibility,
)
from models.message import Message
from models.problem_change import (
    Problem,
    ProblemCaseLink,
    KnownError,
    ChangeRequest,
    MajorIncident,
    MajorIncidentTimeline,
)
from models.user import User
from schemas.problem_change import (
    ProblemCreate,
    ProblemUpdate,
    KnownErrorCreate,
    KnownErrorUpdate,
    ChangeRequestCreate,
    ChangeRequestUpdate,
    CABDecisionCreate,
    MajorIncidentCreate,
    MajorIncidentUpdate,
    MajorIncidentTimelineCreate,
)


class ProblemService:
    """
    ITIL Problem Management Service per SRS §4 & Phase 2 Architecture.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def _generate_problem_number(self) -> str:
        year = datetime.now(timezone.utc).year
        stmt = select(func.count(Problem.id)).where(
            Problem.problem_number.like(f"PRB-{year}-%")
        )
        result = await self.db.execute(stmt)
        count = result.scalar() or 0
        return f"PRB-{year}-{count + 1:04d}"

    async def create_problem(
        self, payload: ProblemCreate, current_user: User
    ) -> Problem:
        if current_user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters cannot create problem records.",
                        "details": {},
                    }
                },
            )

        problem_number = await self._generate_problem_number()
        problem = Problem(
            problem_number=problem_number,
            title=payload.title,
            description=payload.description,
            priority=payload.priority,
            root_cause=payload.root_cause,
            workaround=payload.workaround,
            owner_id=payload.owner_id or current_user.id,
            status=ProblemStatus.OPEN,
        )
        self.db.add(problem)
        await self.db.flush()

        # Link initial cases if supplied
        if payload.case_ids:
            for c_id in payload.case_ids:
                link = ProblemCaseLink(
                    problem_id=problem.id,
                    case_id=c_id,
                    linked_by=current_user.id,
                )
                self.db.add(link)

        # Audit log
        audit = AuditLog(
            target_type="Problem",
            target_id=problem.id,
            action="CREATE_PROBLEM",
            actor_id=current_user.id,
            after_value={
                "problem_number": problem_number,
                "title": problem.title,
                "priority": problem.priority.value,
            },
        )
        self.db.add(audit)
        await self.db.commit()

        return await self.get_problem(problem.id)

    async def get_problem(self, problem_id: uuid.UUID) -> Problem:
        stmt = (
            select(Problem)
            .where(Problem.id == problem_id)
            .options(
                selectinload(Problem.case_links),
                selectinload(Problem.known_errors),
            )
        )
        result = await self.db.execute(stmt)
        problem = result.scalar_one_or_none()
        if not problem:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "PROBLEM_NOT_FOUND",
                        "message": f"Problem {problem_id} does not exist.",
                        "details": {},
                    }
                },
            )
        return problem

    async def list_problems(
        self,
        status_filter: Optional[ProblemStatus] = None,
        priority_filter: Optional[CasePriority] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[Problem], int]:
        stmt = (
            select(Problem)
            .options(
                selectinload(Problem.case_links),
                selectinload(Problem.known_errors),
            )
            .order_by(Problem.created_at.desc())
        )
        count_stmt = select(func.count(Problem.id))

        if status_filter:
            stmt = stmt.where(Problem.status == status_filter)
            count_stmt = count_stmt.where(Problem.status == status_filter)
        if priority_filter:
            stmt = stmt.where(Problem.priority == priority_filter)
            count_stmt = count_stmt.where(Problem.priority == priority_filter)

        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        res = await self.db.execute(stmt.limit(limit).offset(offset))
        problems = list(res.scalars().all())
        return problems, total

    async def update_problem(
        self, problem_id: uuid.UUID, payload: ProblemUpdate, current_user: User
    ) -> Problem:
        if current_user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters cannot modify problems.",
                        "details": {},
                    }
                },
            )

        problem = await self.get_problem(problem_id)
        old_status = problem.status

        if payload.title is not None:
            problem.title = payload.title
        if payload.description is not None:
            problem.description = payload.description
        if payload.status is not None:
            problem.status = payload.status
            if payload.status == ProblemStatus.RESOLVED and not problem.resolved_at:
                problem.resolved_at = datetime.now(timezone.utc)
        if payload.priority is not None:
            problem.priority = payload.priority
        if payload.root_cause is not None:
            problem.root_cause = payload.root_cause
        if payload.workaround is not None:
            problem.workaround = payload.workaround
        if payload.owner_id is not None:
            problem.owner_id = payload.owner_id

        audit = AuditLog(
            target_type="Problem",
            target_id=problem.id,
            action="UPDATE_PROBLEM",
            actor_id=current_user.id,
            before_value={"status": old_status.value},
            after_value={"status": problem.status.value},
        )
        self.db.add(audit)
        await self.db.commit()
        return await self.get_problem(problem.id)

    async def link_case(
        self, problem_id: uuid.UUID, case_id: uuid.UUID, current_user: User
    ) -> ProblemCaseLink:
        problem = await self.get_problem(problem_id)
        # Check case exists
        case_stmt = select(Case).where(Case.id == case_id)
        case_res = await self.db.execute(case_stmt)
        case = case_res.scalar_one_or_none()
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "CASE_NOT_FOUND", "message": f"Case {case_id} not found."}},
            )

        # Check existing link
        link_stmt = select(ProblemCaseLink).where(
            ProblemCaseLink.problem_id == problem_id,
            ProblemCaseLink.case_id == case_id,
        )
        existing = (await self.db.execute(link_stmt)).scalar_one_or_none()
        if existing:
            return existing

        link = ProblemCaseLink(
            problem_id=problem.id,
            case_id=case.id,
            linked_by=current_user.id,
        )
        self.db.add(link)
        await self.db.commit()
        await self.db.refresh(link)
        return link

    async def unlink_case(
        self, problem_id: uuid.UUID, case_id: uuid.UUID, current_user: User
    ) -> bool:
        link_stmt = select(ProblemCaseLink).where(
            ProblemCaseLink.problem_id == problem_id,
            ProblemCaseLink.case_id == case_id,
        )
        link = (await self.db.execute(link_stmt)).scalar_one_or_none()
        if not link:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "LINK_NOT_FOUND", "message": "Case is not linked to this problem."}},
            )
        await self.db.delete(link)
        await self.db.commit()
        return True

    async def create_known_error(
        self, problem_id: uuid.UUID, payload: KnownErrorCreate, current_user: User
    ) -> KnownError:
        problem = await self.get_problem(problem_id)
        ke = KnownError(
            problem_id=problem.id,
            title=payload.title,
            symptoms=payload.symptoms,
            workaround=payload.workaround,
            permanent_fix=payload.permanent_fix,
            published=payload.published,
        )
        self.db.add(ke)
        problem.status = ProblemStatus.KNOWN_ERROR
        await self.db.commit()
        await self.db.refresh(ke)
        return ke


class ChangeService:
    """
    ITIL Change Management Service with CAB Governance.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def _generate_change_number(self) -> str:
        year = datetime.now(timezone.utc).year
        stmt = select(func.count(ChangeRequest.id)).where(
            ChangeRequest.change_number.like(f"CHG-{year}-%")
        )
        result = await self.db.execute(stmt)
        count = result.scalar() or 0
        return f"CHG-{year}-{count + 1:04d}"

    async def create_change_request(
        self, payload: ChangeRequestCreate, current_user: User
    ) -> ChangeRequest:
        if current_user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "PERMISSION_DENIED", "message": "Requesters cannot create change requests."}},
            )

        change_number = await self._generate_change_number()
        initial_status = (
            ChangeStatus.SCHEDULED
            if payload.change_type == ChangeType.STANDARD
            else ChangeStatus.PENDING_CAB
        )

        change = ChangeRequest(
            change_number=change_number,
            title=payload.title,
            description=payload.description,
            reason=payload.reason,
            risk_level=payload.risk_level,
            change_type=payload.change_type,
            status=initial_status,
            requester_id=current_user.id,
            problem_id=payload.problem_id,
            implementation_plan=payload.implementation_plan,
            test_plan=payload.test_plan,
            rollback_plan=payload.rollback_plan,
            scheduled_start=payload.scheduled_start,
            scheduled_end=payload.scheduled_end,
        )
        self.db.add(change)
        await self.db.commit()
        await self.db.refresh(change)
        return change

    async def get_change_request(self, change_id: uuid.UUID) -> ChangeRequest:
        stmt = select(ChangeRequest).where(ChangeRequest.id == change_id)
        result = await self.db.execute(stmt)
        change = result.scalar_one_or_none()
        if not change:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "CHANGE_NOT_FOUND", "message": f"Change request {change_id} not found."}},
            )
        return change

    async def list_change_requests(
        self,
        status_filter: Optional[ChangeStatus] = None,
        type_filter: Optional[ChangeType] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[ChangeRequest], int]:
        stmt = select(ChangeRequest).order_by(ChangeRequest.created_at.desc())
        count_stmt = select(func.count(ChangeRequest.id))

        if status_filter:
            stmt = stmt.where(ChangeRequest.status == status_filter)
            count_stmt = count_stmt.where(ChangeRequest.status == status_filter)
        if type_filter:
            stmt = stmt.where(ChangeRequest.change_type == type_filter)
            count_stmt = count_stmt.where(ChangeRequest.change_type == type_filter)

        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        res = await self.db.execute(stmt.limit(limit).offset(offset))
        changes = list(res.scalars().all())
        return changes, total

    async def cab_decision(
        self, change_id: uuid.UUID, payload: CABDecisionCreate, current_user: User
    ) -> ChangeRequest:
        if current_user.role not in (UserRole.MANAGER, UserRole.ADMINISTRATOR, UserRole.TEAM_LEAD):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "PERMISSION_DENIED", "message": "Only CAB members / Leads can review changes."}},
            )

        change = await self.get_change_request(change_id)
        if change.status != ChangeStatus.PENDING_CAB:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "INVALID_STATE", "message": "Change is not pending CAB decision."}},
            )

        change.cab_approver_id = current_user.id
        change.cab_feedback = payload.feedback
        change.status = ChangeStatus.APPROVED if payload.approved else ChangeStatus.REJECTED

        audit = AuditLog(
            target_type="ChangeRequest",
            target_id=change.id,
            action="CAB_DECISION",
            actor_id=current_user.id,
            after_value={"approved": payload.approved, "feedback": payload.feedback},
        )
        self.db.add(audit)
        await self.db.commit()
        await self.db.refresh(change)
        return change

    async def update_change_status(
        self, change_id: uuid.UUID, new_status: ChangeStatus, current_user: User
    ) -> ChangeRequest:
        change = await self.get_change_request(change_id)
        change.status = new_status
        await self.db.commit()
        await self.db.refresh(change)
        return change


class MajorIncidentService:
    """
    Major Incident Management & War-room Service for P1 Outages.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def _generate_incident_number(self) -> str:
        year = datetime.now(timezone.utc).year
        stmt = select(func.count(MajorIncident.id)).where(
            MajorIncident.incident_number.like(f"MAJ-{year}-%")
        )
        result = await self.db.execute(stmt)
        count = result.scalar() or 0
        return f"MAJ-{year}-{count + 1:04d}"

    async def declare_major_incident(
        self, payload: MajorIncidentCreate, current_user: User
    ) -> MajorIncident:
        if current_user.role not in (UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "PERMISSION_DENIED", "message": "Requesters cannot declare major incidents."}},
            )

        # Validate case exists and is P1
        case_stmt = select(Case).where(Case.id == payload.case_id)
        case_res = await self.db.execute(case_stmt)
        case = case_res.scalar_one_or_none()
        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "CASE_NOT_FOUND", "message": f"Case {payload.case_id} not found."}},
            )

        incident_number = await self._generate_incident_number()
        maj = MajorIncident(
            incident_number=incident_number,
            case_id=case.id,
            title=payload.title,
            status=MajorIncidentStatus.DECLARED,
            commander_id=current_user.id,
            bridge_url=payload.bridge_url or "https://meet.google.com/finora-war-room",
            communications_lead_id=payload.communications_lead_id or current_user.id,
            impact_summary=payload.impact_summary or f"P1 Major Outage declared for {case.title}",
        )
        self.db.add(maj)
        await self.db.flush()

        # Add initial timeline event
        tl = MajorIncidentTimeline(
            major_incident_id=maj.id,
            author_id=current_user.id,
            summary=f"Major Incident {incident_number} declared",
            details=f"Commander {current_user.email} established incident war-room bridge.",
        )
        self.db.add(tl)

        # Audit
        audit = AuditLog(
            target_type="MajorIncident",
            target_id=maj.id,
            action="DECLARE_MAJOR_INCIDENT",
            actor_id=current_user.id,
            after_value={"incident_number": incident_number, "case_id": str(case.id)},
        )
        self.db.add(audit)
        await self.db.commit()

        return await self.get_major_incident(maj.id)

    async def get_major_incident(self, incident_id: uuid.UUID) -> MajorIncident:
        stmt = (
            select(MajorIncident)
            .where(MajorIncident.id == incident_id)
            .options(selectinload(MajorIncident.timeline_events))
        )
        result = await self.db.execute(stmt)
        maj = result.scalar_one_or_none()
        if not maj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "INCIDENT_NOT_FOUND", "message": "Major incident not found."}},
            )
        return maj

    async def list_major_incidents(
        self,
        status_filter: Optional[MajorIncidentStatus] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[MajorIncident], int]:
        stmt = (
            select(MajorIncident)
            .options(selectinload(MajorIncident.timeline_events))
            .order_by(MajorIncident.declared_at.desc())
        )
        count_stmt = select(func.count(MajorIncident.id))

        if status_filter:
            stmt = stmt.where(MajorIncident.status == status_filter)
            count_stmt = count_stmt.where(MajorIncident.status == status_filter)

        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        res = await self.db.execute(stmt.limit(limit).offset(offset))
        incidents = list(res.scalars().all())
        return incidents, total

    async def add_timeline_event(
        self,
        incident_id: uuid.UUID,
        payload: MajorIncidentTimelineCreate,
        current_user: User,
    ) -> MajorIncidentTimeline:
        maj = await self.get_major_incident(incident_id)
        tl = MajorIncidentTimeline(
            major_incident_id=maj.id,
            author_id=current_user.id,
            summary=payload.summary,
            details=payload.details,
        )
        self.db.add(tl)
        await self.db.commit()
        await self.db.refresh(tl)
        return tl

    async def update_major_incident(
        self,
        incident_id: uuid.UUID,
        payload: MajorIncidentUpdate,
        current_user: User,
    ) -> MajorIncident:
        maj = await self.get_major_incident(incident_id)

        if payload.title is not None:
            maj.title = payload.title
        if payload.status is not None:
            maj.status = payload.status
            if payload.status == MajorIncidentStatus.MITIGATED and not maj.mitigated_at:
                maj.mitigated_at = datetime.now(timezone.utc)
            elif payload.status == MajorIncidentStatus.RESOLVED and not maj.resolved_at:
                maj.resolved_at = datetime.now(timezone.utc)
        if payload.commander_id is not None:
            maj.commander_id = payload.commander_id
        if payload.bridge_url is not None:
            maj.bridge_url = payload.bridge_url
        if payload.communications_lead_id is not None:
            maj.communications_lead_id = payload.communications_lead_id
        if payload.executive_summary is not None:
            maj.executive_summary = payload.executive_summary
        if payload.impact_summary is not None:
            maj.impact_summary = payload.impact_summary
        if payload.post_mortem_url is not None:
            maj.post_mortem_url = payload.post_mortem_url

        await self.db.commit()
        return await self.get_major_incident(maj.id)
