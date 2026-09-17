from enum import Enum


class UserRole(str, Enum):
    REQUESTER = "requester"
    OPERATOR = "operator"
    TEAM_LEAD = "team_lead"
    MANAGER = "manager"
    ADMINISTRATOR = "administrator"


class AuthProvider(str, Enum):
    PASSWORD = "password"
    GOOGLE = "google"


class AvailabilityStatus(str, Enum):
    AVAILABLE = "available"
    AWAY = "away"
    OFFLINE = "offline"


class CaseType(str, Enum):
    INCIDENT = "incident"
    SERVICE_REQUEST = "service_request"
    PROBLEM = "problem"
    CHANGE = "change"


class CaseStatus(str, Enum):
    DRAFT = "draft"
    NEW = "new"
    IN_ASSESSMENT = "in_assessment"
    ASSIGNED = "assigned"
    AWAITING_REQUESTER = "awaiting_requester"
    AWAITING_APPROVAL = "awaiting_approval"
    RESOLVED = "resolved"
    CLOSED = "closed"
    CANCELLED = "cancelled"


class CasePriority(str, Enum):
    P1 = "p1"
    P2 = "p2"
    P3 = "p3"
    P4 = "p4"


class RelationshipType(str, Enum):
    RELATED_TO = "related_to"
    DUPLICATE_OF = "duplicate_of"
    PART_OF_MAJOR_INCIDENT = "part_of_major_incident"


class MessageVisibility(str, Enum):
    REQUESTER_VISIBLE = "requester_visible"
    INTERNAL_ONLY = "internal_only"


class ConfidenceLevel(str, Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"


class RiskLevel(str, Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    CRITICAL = "critical"


class EscalationTrigger(str, Enum):
    APPROACHING_DEADLINE = "approaching_deadline"
    MISSED_DEADLINE = "missed_deadline"
    HIGH_RISK = "high_risk"
    REPEATED_REOPEN = "repeated_reopen"
    OPERATOR_REQUESTED = "operator_requested"


class EscalationStatus(str, Enum):
    OPEN = "open"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"


class DraftType(str, Enum):
    INFO_REQUEST = "info_request"
    PROGRESS_UPDATE = "progress_update"
    RESOLUTION = "resolution"
    ESCALATION_SUMMARY = "escalation_summary"


class DraftStatus(str, Enum):
    DRAFT = "draft"
    SENT = "sent"
    DISCARDED = "discarded"


class ApprovalDecision(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class KnowledgeState(str, Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class NotificationEventType(str, Enum):
    CASE_CREATED = "case_created"
    CASE_ASSIGNED = "case_assigned"
    NEW_MESSAGE = "new_message"
    CASE_RESOLVED = "case_resolved"
    CASE_REOPENED = "case_reopened"
    SLA_WARNING = "sla_warning"
    SLA_BREACH = "sla_breach"
    ESCALATION_RAISED = "escalation_raised"

