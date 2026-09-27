import hmac
import hashlib
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Tuple, Optional, List
from uuid import UUID
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from core.config import settings
from models.alert import InboundAlert, AlertRule
from models.case import Case
from models.user import User, Team
from models.sla import SLA
from models.enums import AlertProvider, AlertStatus, CaseType, CasePriority, CaseStatus, UserRole
from services.case_service import CaseService


class AlertIngestionService:
    @staticmethod
    def verify_webhook_auth(
        provider: AlertProvider,
        headers: Dict[str, str],
        query_params: Dict[str, str],
    ) -> bool:
        """
        Validates inbound webhook authentication using constant-time comparison.
        Checks provider-specific environment secret or fallback ALERT_WEBHOOK_SECRET.
        """
        expected_secret = ""
        if provider == AlertProvider.PROMETHEUS and settings.PROMETHEUS_WEBHOOK_SECRET:
            expected_secret = settings.PROMETHEUS_WEBHOOK_SECRET
        elif provider == AlertProvider.DATADOG and settings.DATADOG_WEBHOOK_SECRET:
            expected_secret = settings.DATADOG_WEBHOOK_SECRET
        elif provider == AlertProvider.SENTRY and settings.SENTRY_WEBHOOK_SECRET:
            expected_secret = settings.SENTRY_WEBHOOK_SECRET
        elif provider == AlertProvider.CLOUDWATCH and settings.CLOUDWATCH_WEBHOOK_SECRET:
            expected_secret = settings.CLOUDWATCH_WEBHOOK_SECRET
        else:
            expected_secret = settings.ALERT_WEBHOOK_SECRET

        # If no secret is configured in environment, allow ingestion for local dev/testing
        if not expected_secret:
            return True

        # Extract secret from standard headers or query params
        # (Case-insensitive headers mapping expected)
        provided_secret = (
            headers.get("x-webhook-secret")
            or headers.get("x-alert-secret")
            or headers.get("x-datadog-webhook-secret")
            or headers.get("x-sentry-token")
            or headers.get("x-cloudwatch-secret")
            or query_params.get("secret")
            or query_params.get("token")
        )

        if not provided_secret and "authorization" in headers:
            auth_header = headers["authorization"]
            if auth_header.lower().startswith("bearer "):
                provided_secret = auth_header[7:].strip()

        if not provided_secret:
            return False

        return hmac.compare_digest(provided_secret.strip(), expected_secret.strip())

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
        organization_id: Optional[UUID] = None,
    ) -> InboundAlert:
        """
        Parses inbound payload, checks for duplicates within tenant scope, applies matching alert rules,
        and optionally auto-creates a linked Incident ticket.
        """
        ext_id, title, severity, description, fingerprint = AlertIngestionService.parse_payload(provider, payload)

        # Check deduplication window (last 15 mins) scoped to tenant
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=15)
        stmt_dup = select(InboundAlert).where(
            InboundAlert.fingerprint == fingerprint,
            InboundAlert.created_at >= cutoff,
        )
        if organization_id:
            stmt_dup = stmt_dup.where(InboundAlert.organization_id.in_([organization_id, None]))

        stmt_dup = stmt_dup.order_by(desc(InboundAlert.created_at))
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
                organization_id=organization_id or recent_dup.organization_id,
            )
            db.add(alert)
            await db.commit()
            await db.refresh(alert)
            return alert

        # Fetch matching active alert rules within tenant scope
        stmt_rules = select(AlertRule).where(
            AlertRule.is_active.is_(True),
            AlertRule.provider.in_([provider, AlertProvider.GENERIC]),
        )
        if organization_id:
            stmt_rules = stmt_rules.where(AlertRule.organization_id.in_([organization_id, None]))

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

            # Resolve or create system monitoring requester scoped to organization
            stmt_user = select(User)
            if organization_id:
                stmt_user = stmt_user.where(User.organization_id == organization_id)
            stmt_user = stmt_user.limit(1)

            user_res = await db.execute(stmt_user)
            system_user = user_res.scalars().first()
            if not system_user:
                # Fallback to any user if tenant has no specific user yet
                fallback_res = await db.execute(select(User).limit(1))
                system_user = fallback_res.scalars().first()

            if not system_user:
                system_user = User(
                    email="monitoring_system@finora.internal",
                    password_hash="system_hash",
                    role=UserRole.ADMINISTRATOR,
                    site="System",
                    email_verified=True,
                    organization_id=organization_id,
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
                organization_id=organization_id,
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
            organization_id=organization_id,
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
        user_organization_id: Optional[UUID] = None,
    ) -> Optional[InboundAlert]:
        """
        Acknowledges an alert, strictly enforcing organization tenant boundary.
        """
        stmt = select(InboundAlert).where(InboundAlert.id == alert_id)
        res = await db.execute(stmt)
        alert = res.scalars().first()
        if not alert:
            return None

        # Cross-tenant isolation check
        if user_organization_id and alert.organization_id and alert.organization_id != user_organization_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Cross-tenant alert acknowledgement is prohibited."}},
            )

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
        organization_id: Optional[UUID] = None,
        limit: int = 50,
    ) -> List[InboundAlert]:
        """
        Lists alerts scoped strictly to the caller's organization.
        """
        stmt = select(InboundAlert).order_by(desc(InboundAlert.created_at)).limit(limit)
        if organization_id:
            stmt = stmt.where(InboundAlert.organization_id.in_([organization_id, None]))
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
        organization_id: Optional[UUID] = None,
    ) -> AlertRule:
        """
        Creates an alert routing rule with tenant team isolation verification.
        """
        if target_team_id:
            stmt_team = select(Team).where(Team.id == target_team_id)
            team_res = await db.execute(stmt_team)
            target_team = team_res.scalars().first()
            if not target_team:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={"error": {"code": "TEAM_NOT_FOUND", "message": "Target team does not exist."}},
                )
            if organization_id and target_team.organization_id and target_team.organization_id != organization_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={"error": {"code": "FORBIDDEN", "message": "Target team belongs to another organization."}},
                )

        rule = AlertRule(
            name=name,
            provider=provider,
            match_severity=match_severity,
            match_keyword=match_keyword,
            auto_create_incident=auto_create_incident,
            incident_priority=incident_priority,
            target_team_id=target_team_id,
            organization_id=organization_id,
        )
        db.add(rule)
        await db.commit()
        await db.refresh(rule)
        return rule

    @staticmethod
    async def list_rules(
        db: AsyncSession,
        organization_id: Optional[UUID] = None,
    ) -> List[AlertRule]:
        """
        Lists alert rules scoped strictly to the caller's organization.
        """
        stmt = select(AlertRule).order_by(desc(AlertRule.created_at))
        if organization_id:
            stmt = stmt.where(AlertRule.organization_id.in_([organization_id, None]))
        res = await db.execute(stmt)
        return list(res.scalars().all())

