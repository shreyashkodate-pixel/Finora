from datetime import datetime, timezone
from typing import List, Dict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from models.case import Case
from models.user import User, Team
from models.sla import SLA
from models.enums import CaseStatus, CasePriority, UserRole
from schemas.analytics import (
    WorkloadForecastResponse,
    PredictiveRiskItem,
    PredictiveRiskResponse,
    TeamCapacityMetricItem,
    TeamCapacityOverviewResponse,
)


class PredictiveAnalyticsService:
    @staticmethod
    async def generate_workload_forecast(
        db: AsyncSession,
        horizon_days: int = 7,
    ) -> WorkloadForecastResponse:
        """
        Generates statistical workload predictions for incoming ticket volume,
        priority breakdown, category distribution, and capacity planning advice.
        """
        # Count total historical cases
        stmt_count = select(func.count(Case.id))
        count_res = await db.execute(stmt_count)
        historical_total = count_res.scalar() or 10

        # Estimate daily arrival rate (baseline 5 tickets/day if low count)
        daily_rate = max(5.0, round(historical_total / 30.0, 1))
        expected_total = int(daily_rate * horizon_days)

        pred_p1 = max(1, int(expected_total * 0.08))
        pred_p2 = max(2, int(expected_total * 0.22))
        pred_p3_p4 = max(0, expected_total - pred_p1 - pred_p2)

        categories = {
            "Network & Connectivity": int(expected_total * 0.35),
            "Identity & Access Management": int(expected_total * 0.25),
            "Software & Applications": int(expected_total * 0.25),
            "Hardware & Peripherals": int(expected_total * 0.15),
        }

        margin = int(expected_total * 0.15)
        conf_interval = {
            "lower_bound": max(1, expected_total - margin),
            "upper_bound": expected_total + margin,
        }

        if expected_total > 50:
            rec = f"Anticipated volume of ~{expected_total} cases over {horizon_days} days. Recommended L1 operator staffing: 3-4 concurrent shifts."
        else:
            rec = f"Stable volume of ~{expected_total} cases expected over {horizon_days} days. Current staffing levels are adequate."

        return WorkloadForecastResponse(
            horizon_days=horizon_days,
            forecast_date=datetime.now(timezone.utc),
            predicted_total_cases=expected_total,
            predicted_p1_cases=pred_p1,
            predicted_p2_cases=pred_p2,
            predicted_p3_p4_cases=pred_p3_p4,
            category_breakdown=categories,
            confidence_interval=conf_interval,
            recommendation=rec,
        )

    @staticmethod
    async def get_predictive_risk_forecast(db: AsyncSession) -> PredictiveRiskResponse:
        """
        Identifies active tickets with high statistical likelihood of breaching SLA deadlines.
        """
        now = datetime.now(timezone.utc)
        stmt = (
            select(Case, SLA)
            .join(SLA, SLA.case_id == Case.id)
            .where(
                Case.status.in_([
                    CaseStatus.NEW,
                    CaseStatus.IN_ASSESSMENT,
                    CaseStatus.ASSIGNED,
                    CaseStatus.AWAITING_REQUESTER,
                    CaseStatus.AWAITING_APPROVAL,
                ]),
                SLA.resolution_breached.is_(False),
            )
        )
        res = await db.execute(stmt)
        rows = res.all()

        at_risk_items: List[PredictiveRiskItem] = []

        for case, sla in rows:
            resolve_target = sla.target_resolve_at
            if resolve_target.tzinfo is None:
                resolve_target = resolve_target.replace(tzinfo=timezone.utc)

            total_window = (resolve_target - case.created_at.replace(tzinfo=timezone.utc)).total_seconds()
            remaining_seconds = (resolve_target - now).total_seconds()
            time_to_breach_min = max(0, int(remaining_seconds / 60))

            drivers = []
            prob = 0.1

            if total_window > 0:
                elapsed_pct = (total_window - remaining_seconds) / total_window
                if elapsed_pct >= 0.80:
                    prob = 0.90
                    drivers.append("SLA window is over 80% elapsed")
                elif elapsed_pct >= 0.60:
                    prob = 0.65
                    drivers.append("SLA window is over 60% elapsed")

            if case.priority == CasePriority.P1:
                prob = max(prob, 0.75)
                drivers.append("Priority P1 critical business impact")

            if not case.owner_id and case.status != CaseStatus.NEW:
                prob = min(0.99, prob + 0.20)
                drivers.append("Unassigned owner in active status")

            if prob >= 0.50:
                at_risk_items.append(
                    PredictiveRiskItem(
                        case_id=case.id,
                        reference_number=case.reference_number,
                        title=case.title,
                        priority=case.priority.value,
                        current_status=case.status.value,
                        predicted_breach_probability=round(prob, 2),
                        time_to_breach_minutes=time_to_breach_min,
                        risk_drivers=drivers,
                    )
                )

        at_risk_items.sort(key=lambda x: x.predicted_breach_probability, reverse=True)

        ai_summary = (
            f"Detected {len(at_risk_items)} active tickets with high risk of SLA breach. "
            "Proactive intervention or reassignment is strongly recommended."
            if at_risk_items
            else "All active queues are healthy with no imminent SLA breach risks detected."
        )

        return PredictiveRiskResponse(
            total_at_risk_cases=len(at_risk_items),
            high_risk_cases=at_risk_items,
            ai_summary=ai_summary,
        )

    @staticmethod
    async def get_team_capacity_overview(db: AsyncSession) -> TeamCapacityOverviewResponse:
        """
        Calculates operator load, closure velocity, capacity utilization %, and burnout risk index per team.
        """
        stmt_teams = select(Team)
        team_res = await db.execute(stmt_teams)
        teams = team_res.scalars().all()

        metric_items: List[TeamCapacityMetricItem] = []
        total_util = 0.0

        for t in teams:
            # Count active operators
            stmt_ops = select(func.count(User.id)).where(
                User.team_id == t.id,
                User.role.in_([UserRole.OPERATOR, UserRole.TEAM_LEAD]),
            )
            ops_count = (await db.execute(stmt_ops)).scalar() or 1

            # Count open cases
            stmt_cases = select(func.count(Case.id)).where(
                Case.team_id == t.id,
                Case.status.in_([
                    CaseStatus.NEW,
                    CaseStatus.IN_ASSESSMENT,
                    CaseStatus.ASSIGNED,
                    CaseStatus.AWAITING_REQUESTER,
                    CaseStatus.AWAITING_APPROVAL,
                ]),
            )
            open_cases = (await db.execute(stmt_cases)).scalar() or 0

            avg_per_op = round(open_cases / ops_count, 1)
            # Standard daily capacity: 5 cases per operator
            daily_team_capacity = ops_count * 5.0
            util_pct = round((open_cases / daily_team_capacity) * 100.0, 1)

            if util_pct > 120.0:
                burnout = "critical"
            elif util_pct > 90.0:
                burnout = "high"
            elif util_pct > 60.0:
                burnout = "moderate"
            else:
                burnout = "low"

            metric_items.append(
                TeamCapacityMetricItem(
                    team_id=t.id,
                    team_name=t.name,
                    active_operators=ops_count,
                    open_cases=open_cases,
                    avg_cases_per_operator=avg_per_op,
                    capacity_utilization_pct=util_pct,
                    burnout_risk=burnout,
                    estimated_closure_velocity_per_day=round(ops_count * 4.5, 1),
                )
            )
            total_util += util_pct

        overall_pct = round(total_util / max(1, len(teams)), 1) if teams else 0.0

        return TeamCapacityOverviewResponse(
            total_teams=len(teams),
            overall_utilization_pct=overall_pct,
            teams=metric_items,
        )
