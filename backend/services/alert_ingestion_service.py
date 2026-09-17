import hashlib
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Tuple, Optional, List
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from models.alert import InboundAlert, AlertRule
from models.case import Case
from models.user import User
from models.sla import SLA
from models.enums import AlertProvider, AlertStatus, CaseType, CasePriority, CaseStatus, UserRole
from services.case_service import CaseService


class AlertIngestionService:
    @staticmethod
    def parse_payload(provider: AlertProvider, payload: Dict[str, Any]) -> Tuple[str, str, str, str, str]:
        """
        Normalizes provider-specific payloads into standard fields:
        (external_id, title, severity, description, fingerprint)
        """
        if provider == AlertProvider.PROMETHEUS:
            alerts = payload.get("alerts", [payload])
            first = alerts[0] if alerts else {}
            labels = first.get("labels", {})
            annotations = first.get("annotations", {})
            title = labels.get("alertname", payload.get("title", "Prometheus Alert"))
            severity = labels.get("severity", "warning").lower()
            desc_text = annotations.get("summary") or annotations.get("description", str(labels))
            ext_id = first.get("fingerprint") or labels.get("instance", "prom-1")
            fp_raw = f"prometheus_{labels.get('alertname')}_{labels.get('instance')}"
            fingerprint = hashlib.sha256(fp_raw.encode("utf-8")).hexdigest()[:32]
            return str(ext_id), title, severity, desc_text, fingerprint

        elif provider == AlertProvider.DATADOG:
            title = payload.get("event_title") or payload.get("title", "Datadog Monitor Alert")
            severity = payload.get("alert_type", "error").lower()
            if severity in ("error", "critical"):
                severity = "critical"
            desc_text = payload.get("body", "Datadog triggered monitor condition")
            ext_id = str(payload.get("id", "dd-1"))
            fp_raw = f"datadog_{title}_{ext_id}"
            fingerprint = hashlib.sha256(fp_raw.encode("utf-8")).hexdigest()[:32]
            return ext_id, title, severity, desc_text, fingerprint

        elif provider == AlertProvider.SENTRY:
            title = payload.get("event", {}).get("title") or payload.get("message", "Sentry Application Exception")
            severity = payload.get("level", "error").lower()
            desc_text = payload.get("culprit") or payload.get("url", str(payload.get("event", {})))
            ext_id = str(payload.get("id") or payload.get("event", {}).get("event_id", "sentry-1"))
            fp_raw = f"sentry_{title}_{ext_id}"
            fingerprint = hashlib.sha256(fp_raw.encode("utf-8")).hexdigest()[:32]
            return ext_id, title, severity, desc_text, fingerprint

        elif provider == AlertProvider.CLOUDWATCH:
            title = payload.get("AlarmName", "AWS CloudWatch Alarm")
            state = payload.get("NewStateValue", "ALARM")
            severity = "critical" if state == "ALARM" else "warning"
            desc_text = payload.get("AlarmDescription", payload.get("NewStateReason", "CloudWatch state transition"))
            ext_id = payload.get("AlarmArn", title)
            fp_raw = f"cloudwatch_{title}"
            fingerprint = hashlib.sha256(fp_raw.encode("utf-8")).hexdigest()[:32]
            return str(ext_id), title, severity, desc_text, fingerprint

        else:  # GENERIC
            title = payload.get("title", "External Monitoring Alert")
            severity = str(payload.get("severity", "warning")).lower()
            desc_text = payload.get("description", "Generic monitoring alert payload")
            ext_id = str(payload.get("external_id") or payload.get("id", "gen-1"))
            fp_raw = f"generic_{title}_{ext_id}"
            fingerprint = hashlib.sha256(fp_raw.encode("utf-8")).hexdigest()[:32]
            return ext_id, title, severity, desc_text, fingerprint

    @staticmethod
    async def ingest_alert(
        db: AsyncSession,
        provider: AlertProvider,
        payload: Dict[str, Any],
    ) -> InboundAlert:
        """
        Parses inbound payload, checks for duplicates, applies matching alert rules,
        and optionally auto-creates a linked Incident ticket.
        """
        ext_id, title, severity, description, fingerprint = AlertIngestionService.parse_payload(provider, payload)

        # Check deduplication window (last 15 mins)
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=15)
        stmt_dup = select(InboundAlert).where(
            InboundAlert.fingerprint == fingerprint,
            InboundAlert.created_at >= cutoff,
        ).order_by(desc(InboundAlert.created_at))
        dup_res = await db.execute(stmt_dup)
        recent_dup = dup_res.scalars().first()

        if recent_dup and recent_dup.case_id:
            # Correlate to existing incident without spamming new tickets
            alert = InboundAlert(
                provider=provider,
                external_alert_id=ext_id,
                title=title,
                severity=severity,
                description=description,
                fingerprint=fingerprint,
                status=AlertStatus.CORRELATED,
                raw_payload=payload,
                case_id=recent_dup.case_id,
            )
            db.add(alert)
            await db.commit()
            await db.refresh(alert)
            return alert

        # Fetch matching active alert rules
        stmt_rules = select(AlertRule).where(
            AlertRule.is_active.is_(True),
            AlertRule.provider.in_([provider, AlertProvider.GENERIC]),
        )
        rules_res = await db.execute(stmt_rules)
        rules = rules_res.scalars().all()

        matched_rule: Optional[AlertRule] = None
        for r in rules:
            if r.match_severity and r.match_severity.lower() == severity.lower():
                matched_rule = r
                break
            if r.match_keyword and (r.match_keyword.lower() in title.lower() or (description and r.match_keyword.lower() in description.lower())):
                matched_rule = r
                break

        # Fallback rule if severity is critical
        auto_create = False
        priority = CasePriority.P2
        team_id = None
        if matched_rule:
            auto_create = matched_rule.auto_create_incident
            priority = matched_rule.incident_priority
            team_id = matched_rule.target_team_id
        elif severity in ("critical", "error"):
            auto_create = True
            priority = CasePriority.P1 if severity == "critical" else CasePriority.P2

        created_case: Optional[Case] = None
        alert_status = AlertStatus.RECEIVED

        if auto_create:
            case_service = CaseService(db)
            ref_num = await case_service._generate_reference_number(CaseType.INCIDENT)
            now = datetime.now(timezone.utc)

            # Resolve or create system monitoring requester
            stmt_user = select(User).limit(1)
            user_res = await db.execute(stmt_user)
            system_user = user_res.scalars().first()
            if not system_user:
                system_user = User(
                    email="monitoring_system@finora.internal",
                    password_hash="system_hash",
                    role=UserRole.ADMINISTRATOR,
                    site="System",
                    email_verified=True,
                )
                db.add(system_user)
                await db.flush()

            # Create Case
            created_case = Case(
                reference_number=ref_num,
                title=f"[AUTO-ALERT] {title}",
                description=f"Automated incident generated from {provider.value.upper()} monitoring alert.\n\nSeverity: {severity}\nDescription: {description}\nExternal ID: {ext_id}",
                type=CaseType.INCIDENT,
                priority=priority,
                status=CaseStatus.NEW,
                requester_id=system_user.id,
                team_id=team_id,
            )
            db.add(created_case)
            await db.flush()

            # Create SLA targets
            sla = SLA(
                case_id=created_case.id,
                target_response_at=now + timedelta(minutes=15 if priority == CasePriority.P1 else 60),
                target_resolve_at=now + timedelta(hours=4 if priority == CasePriority.P1 else 8),
            )
            db.add(sla)
            await db.flush()

            alert_status = AlertStatus.INCIDENT_CREATED

        alert = InboundAlert(
            provider=provider,
            external_alert_id=ext_id,
            title=title,
            severity=severity,
            description=description,
            fingerprint=fingerprint,
            status=alert_status,
            raw_payload=payload,
            case_id=created_case.id if created_case else None,
        )
        db.add(alert)
        await db.commit()
        await db.refresh(alert)
        return alert

    @staticmethod
    async def acknowledge_alert(
        db: AsyncSession,
        alert_id: UUID,
        user_id: UUID,
    ) -> Optional[InboundAlert]:
        stmt = select(InboundAlert).where(InboundAlert.id == alert_id)
        res = await db.execute(stmt)
        alert = res.scalars().first()
        if not alert:
            return None

        alert.status = AlertStatus.ACKNOWLEDGED
        alert.acknowledged_at = datetime.now(timezone.utc)
        alert.acknowledged_by_id = user_id
        await db.commit()
        await db.refresh(alert)
        return alert

    @staticmethod
    async def list_alerts(
        db: AsyncSession,
        provider: Optional[AlertProvider] = None,
        status: Optional[AlertStatus] = None,
        severity: Optional[str] = None,
        limit: int = 50,
    ) -> List[InboundAlert]:
        stmt = select(InboundAlert).order_by(desc(InboundAlert.created_at)).limit(limit)
        if provider:
            stmt = stmt.where(InboundAlert.provider == provider)
        if status:
            stmt = stmt.where(InboundAlert.status == status)
        if severity:
            stmt = stmt.where(InboundAlert.severity == severity)

        res = await db.execute(stmt)
        return list(res.scalars().all())

    @staticmethod
    async def create_rule(
        db: AsyncSession,
        name: str,
        provider: AlertProvider,
        match_severity: Optional[str],
        match_keyword: Optional[str],
        auto_create_incident: bool,
        incident_priority: CasePriority,
        target_team_id: Optional[UUID],
    ) -> AlertRule:
        rule = AlertRule(
            name=name,
            provider=provider,
            match_severity=match_severity,
            match_keyword=match_keyword,
            auto_create_incident=auto_create_incident,
            incident_priority=incident_priority,
            target_team_id=target_team_id,
        )
        db.add(rule)
        await db.commit()
        await db.refresh(rule)
        return rule

    @staticmethod
    async def list_rules(db: AsyncSession) -> List[AlertRule]:
        stmt = select(AlertRule).order_by(desc(AlertRule.created_at))
        res = await db.execute(stmt)
        return list(res.scalars().all())
