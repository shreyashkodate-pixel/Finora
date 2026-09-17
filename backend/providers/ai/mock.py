import logging
from typing import Dict, Any, Optional

from models.enums import CasePriority, ConfidenceLevel, RiskLevel, DraftType
from providers.ai.base import (
    AIProvider,
    AITriageData,
    CaseRiskData,
    AIDraftData,
    score_to_confidence_level,
)

logger = logging.getLogger("helpdesk.providers.ai.mock")


class MockAIProvider(AIProvider):
    """
    Deterministic mock AI provider for testing and local development
    when external API keys are not provided.
    """

    async def triage_case(
        self,
        title: str,
        description: str,
        context: Optional[Dict[str, Any]] = None,
    ) -> AITriageData:
        logger.info(f"Mock AI Triage running for case: '{title}'")
        text = f"{title} {description}".lower()

        # Deterministic heuristic categorization
        if any(k in text for k in ["vpn", "wifi", "network", "firewall", "dns", "connection"]):
            category = "Network & Connectivity"
            team = "Network Operations"
            severity = "High" if "down" in text or "cannot connect" in text else "Medium"
            priority = CasePriority.P2 if severity == "High" else CasePriority.P3
            score = 0.88
            missing_info = ["Specific error message or code", "Are other users in the same office affected?"]
            factors = ["Network-related terminology detected in incident report", "Potential multi-user connectivity impact"]
        elif any(k in text for k in ["password", "login", "sso", "mfa", "2fa", "locked", "account"]):
            category = "Identity & Access"
            team = "Service Desk Tier 1"
            severity = "Medium"
            priority = CasePriority.P3
            score = 0.92
            missing_info = ["Username or corporate email address", "Timestamp of last successful login"]
            factors = ["Authentication and identity credentials referenced", "Standard self-service or desk procedure"]
        elif any(k in text for k in ["crash", "outage", "production", "server down", "emergency", "database"]):
            category = "Infrastructure & Servers"
            team = "Infrastructure Engineering"
            severity = "Critical"
            priority = CasePriority.P1
            score = 0.95
            missing_info = ["Hostnames or IP addresses affected", "Application error stack trace"]
            factors = ["High-impact system outage keywords detected", "Potential critical service degradation"]
        elif any(k in text for k in ["laptop", "monitor", "keyboard", "printer", "hardware", "dock"]):
            category = "Hardware & Peripherals"
            team = "Desktop Support"
            severity = "Low"
            priority = CasePriority.P4
            score = 0.82
            missing_info = ["Asset tag number or serial number", "Device model and operating system"]
            factors = ["Physical endpoint hardware components identified"]
        else:
            category = "General IT Inquiries"
            team = "Service Desk Tier 1"
            severity = "Low"
            priority = CasePriority.P4
            score = 0.65
            missing_info = ["Detailed steps to reproduce the issue", "Exact system or application name"]
            factors = ["Unclassified request; default generic routing applied"]

        return AITriageData(
            suggested_category=category,
            suggested_severity=severity,
            suggested_priority=priority,
            confidence_score=score,
            confidence_level=score_to_confidence_level(score),
            supporting_factors=factors,
            missing_info=missing_info,
            suggested_team_name=team,
            recommended_next_action=f"Assign to {team} and request clarification regarding: {', '.join(missing_info[:1])}",
        )

    async def summarize_case(
        self,
        title: str,
        history_text: str,
        new_message_text: str,
    ) -> str:
        logger.info(f"Mock AI Summarization running for '{title}'")
        msg_snippet = new_message_text.strip()
        if len(msg_snippet) > 80:
            msg_snippet = msg_snippet[:77] + "..."

        if not history_text.strip():
            return f"Initial Report: Incident '{title}' submitted. Latest update: {msg_snippet}. Investigation in progress."
        
        return (
            f"Case '{title}' Summary:\n"
            f"- Reported Issue: Active investigation underway.\n"
            f"- Recent Activity: Operator/Requester communication updated.\n"
            f"- Latest Note: {msg_snippet}\n"
            f"- Current Status: Awaiting next troubleshooting step or user feedback."
        )

    async def assess_risk(
        self,
        case_context: Dict[str, Any],
    ) -> CaseRiskData:
        logger.info("Mock AI Risk Assessment running")
        inactivity_hours = float(case_context.get("inactivity_hours", 0))
        hours_to_deadline = float(case_context.get("hours_to_deadline", 24))
        reopen_count = int(case_context.get("reopen_count", 0))
        priority = str(case_context.get("priority", "p3")).lower()

        signals = {
            "inactivity_hours": inactivity_hours,
            "hours_to_deadline": hours_to_deadline,
            "reopen_count": reopen_count,
            "priority": priority,
        }

        if hours_to_deadline <= 0:
            level = RiskLevel.CRITICAL
            score = 0.99
            rationale = f"SLA deadline breached by {abs(hours_to_deadline):.1f} hours."
        elif hours_to_deadline <= 2 and priority in ["p1", "p2"]:
            level = RiskLevel.CRITICAL
            score = 0.90
            rationale = f"High priority ({priority.upper()}) within {hours_to_deadline:.1f}h of SLA deadline."
        elif reopen_count >= 2 or hours_to_deadline <= 4:
            level = RiskLevel.HIGH
            score = 0.80
            rationale = f"Case reopened {reopen_count} times or SLA expiration approaching ({hours_to_deadline:.1f}h)."
        elif inactivity_hours >= 24 or reopen_count == 1:
            level = RiskLevel.MODERATE
            score = 0.55
            rationale = f"Inactive for {inactivity_hours:.1f}h without recent operator progress."
        else:
            level = RiskLevel.LOW
            score = 0.15
            rationale = "Operating within normal SLA parameters."

        return CaseRiskData(
            risk_level=level,
            risk_score=score,
            signals=signals,
            rationale=rationale,
        )

    async def draft_communication(
        self,
        draft_type: DraftType,
        case_context: Dict[str, Any],
        custom_instructions: Optional[str] = None,
    ) -> AIDraftData:
        logger.info(f"Mock AI Drafting communication of type: {draft_type}")
        title = case_context.get("title", "your request")
        requester_name = case_context.get("requester_name", "Valued Colleague")

        if draft_type == DraftType.INFO_REQUEST:
            subject = f"Information Needed: {title}"
            body = (
                f"Hello {requester_name},\n\n"
                f"We are currently investigating your request regarding \"{title}\". "
                f"To help us resolve this swiftly, could you please provide:\n"
                f"1. Any specific error message or screenshot you encountered.\n"
                f"2. Your current office location or network environment.\n\n"
                f"Thank you for your assistance.\n"
                f"IT Support Desk"
            )
        elif draft_type == DraftType.PROGRESS_UPDATE:
            subject = f"Update on your request: {title}"
            body = (
                f"Hello {requester_name},\n\n"
                f"This is an update regarding your issue \"{title}\". Our engineering team "
                f"has isolated the root cause and is actively deploying a corrective fix. "
                f"We expect to provide another update within the next 2 hours.\n\n"
                f"Best regards,\n"
                f"IT Support Desk"
            )
        elif draft_type == DraftType.RESOLUTION:
            subject = f"Resolved: {title}"
            body = (
                f"Hello {requester_name},\n\n"
                f"We have addressed and verified the solution for \"{title}\". "
                f"The service has been restored to normal operations.\n\n"
                f"Please verify on your end and let us know if everything is functioning as expected. "
                f"If you continue experiencing issues, you may reply to this message within 7 days to reopen the case.\n\n"
                f"Sincerely,\n"
                f"IT Support Desk"
            )
        elif draft_type == DraftType.ESCALATION_SUMMARY:
            subject = f"Escalation Notice: {title}"
            body = (
                f"Attention Team Lead / Management,\n\n"
                f"Case: \"{title}\"\n"
                f"This incident requires escalation due to technical complexity or approaching SLA target. "
                f"Current status: In assessment. Immediate resource reassignment or senior operator review is requested.\n\n"
                f"Automated Escalation Assistant"
            )
        else:
            subject = f"Support Notice: {title}"
            body = f"Hello {requester_name},\n\nThank you for reaching out regarding \"{title}\". We are processing your request."

        if custom_instructions:
            body += f"\n\n[Note: Additional instructions considered: {custom_instructions}]"

        return AIDraftData(
            draft_type=draft_type,
            subject=subject,
            body=body,
        )
