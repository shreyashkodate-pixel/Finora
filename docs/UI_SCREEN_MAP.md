# AI Helpdesk --- UI Screen Map

**Version:** 1.0\
**Status:** UI implementation and Stitch handoff specification\
**Source of truth:** `AI_Helpdesk_PRD_Final(1).md`,
`AI_Helpdesk_SRS_Final(1).md`, `frontend_requirements.md`

------------------------------------------------------------------------

## 1. Purpose

This document maps every major UI screen in the AI Helpdesk application
to:

-   User role
-   Screen purpose
-   Entry points
-   Navigation
-   Components
-   Data required
-   User actions
-   API dependencies
-   UI states
-   Responsive behavior
-   Security/visibility rules

This document is a bridge between the product specification,
Stitch-generated UI designs, and Flutter implementation.

------------------------------------------------------------------------

# 2. Global UI Rules

## 2.1 Design System

-   Framework: Flutter
-   Design language: Material 3
-   Visual direction: clean, minimalist, enterprise-grade
-   Inspiration: Linear / Stripe / Vercel
-   Avoid flashy AI/chatbot styling and excessive purple gradients.
-   AI should appear as a quiet, contextual assistant through cards,
    badges, summaries, confidence indicators, recommendations, and
    action panels.

## 2.2 Color System

  Purpose          Color
  ---------------- -----------
  Primary          `#1E40AF`
  Primary Hover    `#1D4ED8`
  Background       `#F8FAFC`
  Surface          `#FFFFFF`
  Border           `#E2E8F0`
  Primary Text     `#0F172A`
  Secondary Text   `#64748B`
  P1               `#DC2626`
  P2               `#EA580C`
  P3               `#2563EB`
  P4               `#64748B`
  Resolved         `#16A34A`
  Warning          `#D97706`
  AI Accent        `#6366F1`

## 2.3 Accessibility

-   WCAG 2.1 AA
-   Minimum contrast ratio: 4.5:1
-   Minimum touch target: 48x48
-   Clear keyboard/focus states on desktop/web
-   Do not rely on color alone to communicate status or priority.

## 2.4 Responsive Navigation

### Desktop

Use a left `NavigationRail` / enterprise navigation shell.

### Tablet

Use a responsive `NavigationRail`.

### Mobile

Use a bottom `NavigationBar`.

------------------------------------------------------------------------

# 3. Global Application Shell

## Screen: Dashboard Shell

### Purpose

Provide the persistent application layout and navigation for
authenticated users.

### Roles

-   Requester
-   Operator L1/L2
-   Team Lead
-   Manager
-   Administrator

### Components

-   Application logo/name
-   Primary navigation
-   User profile menu
-   Notification indicator
-   Organization/team context where applicable
-   Page title
-   Breadcrumbs where useful
-   Main content area
-   Responsive navigation

### Navigation must be role-aware

Requester navigation: - Home - My Tickets - Service Catalog - Knowledge
Base - Notifications - Profile

Operator navigation: - Queue - My Work - Knowledge Base - Problems -
Auto-Fix - Notifications

Team Lead: - Queue - Workload - Approvals - Problems - Knowledge Base -
Notifications

Manager: - Operational Health - Analytics - Approvals / CAB - Major
Incidents - Forecasts - Notifications

Administrator: - Organizations - Teams / Users - Security Policies -
Alert Rules - Device Registry - Audit Logs

------------------------------------------------------------------------

# 4. Authentication Module

## Screen 1 --- Authentication / Dual Sign-In

### Purpose

Authenticate users using local credentials or Google OAuth.

### Roles

Unauthenticated users.

### Entry Point

Application launch.

### Components

-   Product logo
-   Email field
-   Password field
-   Sign In button
-   Register link
-   Google Sign-In button
-   Forgot password flow if implemented
-   Error messages
-   Loading state

### Actions

-   Sign in
-   Register
-   Sign in with Google
-   Recover account

### API Dependencies

-   `POST /api/v1/auth/register`
-   `POST /api/v1/auth/login`
-   `GET /api/v1/auth/google`
-   `GET /api/v1/auth/me`
-   `POST /api/v1/auth/refresh`

### States

-   Initial
-   Loading
-   Validation error
-   Authentication failure
-   OAuth failure
-   Success

### Security

-   Never display access/refresh tokens.
-   Never display secrets.
-   Authentication errors should not expose sensitive account
    information.

------------------------------------------------------------------------

# 5. Requester Module

# Screen 2 --- Requester Home & Service Catalog

### Purpose

Give employees a simple entry point to report issues, request services,
search knowledge, and monitor existing cases.

### Role

Requester.

### Entry Points

-   Login
-   Application home
-   Navigation → Home

### Components

-   Greeting/header
-   Search
-   Quick action cards
    -   Report an Issue
    -   Request a Service
    -   Search Knowledge
-   Active ticket summary
-   SLA/status indicators
-   Recent tickets
-   Suggested knowledge articles

### Actions

-   Create Incident
-   Create Service Request
-   Open ticket
-   Search knowledge
-   View notifications

### Data Required

-   User profile
-   Active cases
-   Case status
-   Priority
-   SLA status
-   Suggested knowledge articles

### API Dependencies

-   `/cases`
-   `/knowledge`
-   `/notifications`

### States

-   Loading
-   Empty active tickets
-   Populated
-   Error

### Responsive

Mobile: - Stacked quick actions - Bottom navigation

Desktop: - Dashboard cards/grid - Expanded active ticket table/list

------------------------------------------------------------------------

# Screen 3 --- Case Intake Wizard

### Purpose

Allow a requester to create an Incident or Service Request.

### Role

Requester.

### Entry Points

-   Requester Home
-   Service Catalog
-   Quick Action

### Steps

1.  Case Type
2.  Title
3.  Description
4.  Urgency / relevant information
5.  Attachments
6.  Suggested Knowledge
7.  Review
8.  Submit

### Components

-   Incident / Service Request selector
-   Title input
-   Description field
-   Urgency selector
-   Attachment uploader
-   Suggested articles
-   Submission summary
-   Submit button

### Actions

-   Select case type
-   Enter details
-   Attach evidence
-   Open suggested article
-   Submit case
-   Cancel

### API Dependencies

-   `POST /cases`
-   `/attachments`
-   `/knowledge`

### States

-   Empty form
-   Validation error
-   Uploading
-   Submitting
-   Success
-   Failure

### Rules

-   Allowed evidence types and size limits must follow the SRS.
-   AI suggestions are advisory and must not silently override requester
    input.

------------------------------------------------------------------------

# Screen 4 --- Requester Ticket Detail & Live Chat

### Purpose

Allow requesters to monitor their case, communicate with IT, provide
evidence, confirm resolution, or reopen within the permitted window.

### Role

Requester.

### Entry Points

-   Home
-   My Tickets
-   Notification
-   Direct case navigation

### Components

-   Case reference
-   Title
-   Status
-   Priority
-   SLA countdown
-   Assignment/team
-   Case timeline
-   Public conversation
-   Attachment list
-   Message composer
-   Resolution information
-   Confirm Resolution
-   Reopen action where permitted

### Visibility

Requester must only see requester-visible information.

Internal notes must never be exposed.

### Actions

-   Send public message
-   Upload attachment
-   View attachment
-   Confirm resolution
-   Reopen within 7-day window

### API Dependencies

-   `/cases/{id}`
-   `/cases/{id}/messages`
-   `/attachments`
-   `/realtime`

### States

-   Loading
-   Active
-   Awaiting requester
-   Resolved
-   Reopen available
-   Closed
-   Error

------------------------------------------------------------------------

# 6. Operator Module

# Screen 5 --- Operator Queue & Workstation

### Purpose

Provide operators with a centralized queue of incidents and service
requests.

### Roles

-   Operator L1
-   Operator L2
-   Team Lead

### Components

-   Queue metrics
-   Search
-   Filters
-   Priority filter
-   Status filter
-   Assignment filter
-   SLA risk filter
-   Ticket table/list
-   Sort controls
-   Bulk selection where permitted

### Table Information

-   Case reference
-   Title
-   Type
-   Priority
-   Status
-   Assignee
-   Team
-   SLA state
-   Updated time

### Actions

-   Open case
-   Assign
-   Reassign
-   Filter
-   Sort
-   Search

### API Dependencies

-   `/cases`
-   `/analytics`
-   `/sweep` where relevant

### States

-   Loading
-   Empty queue
-   Populated
-   Filtered empty result
-   Error

------------------------------------------------------------------------

# Screen 6 --- Operator Workspace & AI Copilot

### Purpose

Provide the main investigation and resolution workspace.

### Roles

-   Operator L1/L2
-   Team Lead
-   Authorized Manager where applicable

### Layout

Desktop split view:

``` text
┌──────────────────────────────┬─────────────────────────────┐
│ Case / Timeline              │ AI Copilot                  │
│                              │                             │
│ Public conversation          │ Living Summary              │
│ Internal notes               │ AI Triage                   │
│ Attachments                  │ SLA Risk                    │
│ Activity timeline            │ Recommended Actions         │
│                              │ Response Draft               │
│                              │ Auto-Fix                     │
└──────────────────────────────┴─────────────────────────────┘
```

### Left Panel

-   Case header
-   Status
-   Priority
-   SLA
-   Requester information
-   Timeline
-   Public messages
-   Internal notes
-   Attachments
-   Case relationships

### Right Panel

-   Living Summary
-   AI Triage
-   Category
-   Suggested priority
-   Suggested team
-   Missing information
-   Similar cases
-   SLA risk
-   Communication draft
-   Recommended troubleshooting
-   What Should I Do Next?
-   Controlled Auto-Fix

### AI Rules

AI is advisory.

AI recommendations must not silently:

-   Change case status
-   Send public communication
-   Execute high-impact actions
-   Approve changes

Human confirmation is required.

### API Dependencies

-   `/cases`
-   `/ai/triage`
-   `/ai/triage/apply`
-   `/ai/summary`
-   `/ai/risk`
-   `/ai/draft`
-   `/autofix`
-   `/knowledge`
-   `/realtime`

### States

-   AI loading
-   AI result
-   AI unavailable
-   Deterministic fallback
-   Low confidence
-   Human override
-   Auto-fix pending approval

------------------------------------------------------------------------

# Screen 7 --- Problem Management & KEDB

### Purpose

Manage recurring/root-cause problems and known errors.

### Roles

-   Operator
-   Team Lead
-   Manager

### Components

-   Problem list
-   Search
-   Filters
-   Problem status
-   Known Error Database
-   Linked incidents
-   Root cause
-   Workaround
-   Permanent fix
-   Knowledge article relationship

### Actions

-   Create problem
-   Link incident
-   Create known error
-   Add workaround
-   Update root cause
-   Resolve problem

### API Dependencies

-   `/itil`
-   `/knowledge`
-   `/cases`

### States

-   Loading
-   Empty
-   Populated
-   Error

------------------------------------------------------------------------

# Screen 8 --- Controlled Auto-Fix Action Console

### Purpose

Allow authorized operators to review and execute approved low-risk
remediation actions.

### Supported Actions

-   `service_restart`
-   `dns_flush`
-   `account_unlock`
-   `cache_clear`

### Roles

Authorized Operator / Team Lead according to SRS permissions.

### Components

-   Proposed action
-   Reason
-   Target
-   Risk information
-   Dry-run result
-   Approval state
-   Execute button
-   Rollback information
-   Execution timeline
-   Audit information

### Safety

The UI must clearly communicate:

``` text
AI Recommendation
        ↓
Human Review
        ↓
Approval
        ↓
Execution
        ↓
Audit
```

### States

-   Suggested
-   Awaiting approval
-   Dry-run
-   Approved
-   Executing
-   Successful
-   Failed
-   Rolled back

### API Dependencies

-   `/autofix`

------------------------------------------------------------------------

# 7. Leadership Module

# Screen 9 --- Manager Operational Health & Insights

### Purpose

Provide managers with cross-team operational visibility.

### Roles

-   Manager
-   Administrator where permitted

### Components

-   Open cases
-   SLA risk
-   Breached cases
-   Team workload
-   Priority distribution
-   Escalations
-   Major incident indicators
-   Operational health cards
-   Trend charts

### Actions

-   Drill into cases
-   Filter by team
-   Filter by priority
-   View SLA risks
-   Open analytics

### API Dependencies

-   `/analytics`
-   `/cases`
-   `/sweep`

### States

-   Loading
-   No data
-   Populated
-   Error

------------------------------------------------------------------------

# Screen 10 --- Approvals & Change Management / CAB

### Purpose

Review and approve controlled changes.

### Roles

-   Operator
-   Team Lead
-   Manager
-   Authorized CAB members

### Change Types

-   Standard
-   Normal
-   Emergency

### Components

-   Approval queue
-   Change request details
-   Risk
-   Impact
-   Proposed implementation
-   Rollback plan
-   Related cases/problems
-   Approval history
-   CAB controls

### Actions

-   Approve
-   Reject
-   Request changes
-   View related case
-   View audit trail

### API Dependencies

-   `/approvals`
-   `/itil`

### States

-   Pending
-   Approved
-   Rejected
-   Changes requested
-   Completed

------------------------------------------------------------------------

# Screen 11 --- Major Incident Commander / War Room

### Purpose

Coordinate major incidents using a shared operational workspace.

### Roles

-   Team Lead
-   Manager
-   Authorized Operators

### Components

-   Major incident header
-   Incident status
-   Severity
-   Impact summary
-   Timeline
-   Participants
-   Linked cases
-   Communication updates
-   Action items
-   Technical updates
-   Escalation state

### Actions

-   Create/update major incident
-   Link cases
-   Add timeline event
-   Add internal update
-   Coordinate participants
-   Publish approved communication

### API Dependencies

-   `/itil`
-   `/cases`
-   `/realtime`

### Realtime

Use WebSockets for live operational updates.

------------------------------------------------------------------------

# Screen 12 --- Predictive Workload & Capacity Forecast

### Purpose

Display predictive workload and capacity information.

### Roles

-   Team Lead
-   Manager
-   Administrator where permitted

### Components

-   7-day intake forecast
-   Capacity view
-   Workload trends
-   SLA burn/risk
-   Team workload
-   Capacity snapshots
-   Forecast confidence/context

### Actions

-   Select team
-   Select date range
-   Drill into workload

### API Dependencies

-   `/analytics`

### States

-   Loading
-   Forecast unavailable
-   Populated
-   Error

------------------------------------------------------------------------

# 8. Enterprise Intelligence Module

# Screen 13 --- Semantic Vector Search & NL Discovery

### Purpose

Allow users to search cases, knowledge, and organizational memory using
semantic or natural-language queries.

### Roles

Role-dependent access.

### Components

-   Search input
-   Natural-language query
-   Filters
-   Result categories
-   Case results
-   Knowledge results
-   Similarity/relevance information
-   Citations
-   Query history where permitted

### Example

``` text
"Show me previous Wi-Fi incidents affecting the Pune office."
```

### API Dependencies

-   `/search`

### States

-   Initial
-   Searching
-   Results
-   No results
-   Error

### Security

Search results must respect tenant, organization, role, and message
visibility rules.

------------------------------------------------------------------------

# Screen 14 --- Inbound APM Monitoring & Alerts

### Purpose

Display monitoring alerts ingested from external systems.

### Supported Sources

-   Prometheus
-   Datadog
-   Sentry
-   CloudWatch

### Components

-   Alert feed
-   Source
-   Severity
-   Timestamp
-   Service
-   Status
-   Related cases
-   Alert rules
-   Case creation state

### Actions

-   View alert
-   Create/link case
-   Acknowledge
-   View related cases

### API Dependencies

-   `/integrations/alerts`

### States

-   No alerts
-   Active alerts
-   Processing
-   Error

------------------------------------------------------------------------

# Screen 15 --- Multi-Tenant SaaS & Security Policies

### Purpose

Allow administrators to manage organizations and tenant-level policies.

### Role

Administrator.

### Components

-   Organization list
-   Organization details
-   Tenant policies
-   Retention configuration
-   Security controls
-   User/team administration
-   Audit access

### Actions

-   Create organization
-   Update organization
-   Configure policies
-   Manage teams/users
-   View audit logs

### API Dependencies

-   `/admin/organizations`

### Security

Administrative controls must only be accessible to authorized users.

------------------------------------------------------------------------

# Screen 16 --- Push Notification Device Registry & Preferences

### Purpose

Manage registered notification devices and user notification
preferences.

### Roles

-   Requester
-   Operator
-   Team Lead
-   Manager
-   Administrator

### Components

-   Registered devices
-   Platform
-   Device status
-   Notification preferences
-   Push channels
-   Enable/disable controls

### Supported Push Channels

-   FCM
-   APNs
-   WebPush

### API Dependencies

-   `/notifications/devices`

### States

-   No devices
-   Registered
-   Disabled
-   Error

------------------------------------------------------------------------

# 9. Shared Knowledge Module

# Screen 17 --- Knowledge Base Browser & AI Auto-Drafter

### Purpose

Allow users to search knowledge and authorized staff to create or review
AI-generated knowledge articles.

### Roles

Knowledge access depends on role.

### Components

-   Knowledge search
-   Categories
-   Article list
-   Article detail
-   Related cases
-   Related problems
-   Workaround
-   Resolution
-   AI draft panel
-   Review controls

### AI Draft Workflow

``` text
Resolved Case
      ↓
AI Knowledge Draft
      ↓
Human Review
      ↓
Edit
      ↓
Approve
      ↓
Publish
```

### Actions

-   Search article
-   Open article
-   Create draft
-   Review AI draft
-   Edit
-   Approve
-   Publish

### API Dependencies

-   `/knowledge`
-   `/ai/draft`
-   `/approvals`

### States

-   Loading
-   Empty
-   Draft
-   Review
-   Published
-   Error

------------------------------------------------------------------------

# 10. Global Case UI Components

These components should remain visually consistent across all
case-related screens.

## Case Header

Display:

-   Case reference
-   Type
-   Title
-   Status
-   Priority
-   Assignee
-   Team
-   SLA state

## Status Pill

Supported lifecycle states:

-   Draft
-   New
-   In Assessment
-   Assigned
-   In Progress
-   Awaiting Approval
-   Awaiting Requester
-   Resolved
-   Fulfilled
-   Closed

## Priority Pill

-   P1
-   P2
-   P3
-   P4

## SLA Countdown

Use monospace typography.

Visual progression:

``` text
Healthy
   ↓
<20% remaining
   ↓
Warning
   ↓
Breach
```

Use both color and textual/icon indicators.

## Timeline

Display:

-   Status changes
-   Assignment changes
-   Public messages
-   Internal notes
-   AI events where appropriate
-   Approvals
-   Auto-fix actions
-   Escalations
-   Attachments

------------------------------------------------------------------------

# 11. Global UI States

Every major screen must design these states.

## Loading

Use skeletons or appropriate progress indicators.

Avoid blank screens.

## Empty

Explain what is empty and provide a useful next action.

Example:

``` text
No active incidents
You're all caught up.
[Create an Incident]
```

## Error

Display a concise human-readable error and recovery action.

Example:

``` text
We couldn't load your cases.
[Try Again]
```

## Permission Denied

Do not expose restricted data.

Example:

``` text
You don't have permission to access this area.
```

## Offline / Backend Unavailable

The UI should clearly indicate unavailable server functionality while
preserving the case-centric experience where applicable.

## AI Unavailable

AI functionality should fail gracefully.

The case workflow must remain usable without AI.

------------------------------------------------------------------------

# 12. AI UI Rules

AI must be integrated into workflows rather than presented as a generic
chatbot.

## AI should appear as

-   AI Triage
-   Living Summary
-   SLA Risk
-   Similar Cases
-   Recommended Troubleshooting
-   Missing Information
-   Communication Draft
-   Knowledge Draft
-   What Should I Do Next?
-   Predictive Insights

## Every important AI recommendation should communicate

-   What the AI recommends
-   Relevant confidence/context where available
-   Human action required
-   Ability to override or dismiss

## Never

-   Automatically execute high-impact actions
-   Hide human approval
-   Make AI look like the authoritative source of truth
-   Block normal case operations when AI is unavailable

------------------------------------------------------------------------

# 13. Role-Based Screen Access

  Screen                 Requester   Operator   Team Lead   Manager   Admin
  -------------------- ----------- ---------- ----------- --------- -------
  Authentication                 ✓          ✓           ✓         ✓       ✓
  Requester Home                 ✓         \-          \-        \-      \-
  Case Intake                    ✓         \-          \-        \-      \-
  Requester Ticket               ✓         \-          \-        \-      \-
  Operator Queue                \-          ✓           ✓        \-      \-
  Operator Workspace            \-          ✓           ✓        \-      \-
  Problem / KEDB                \-          ✓           ✓         ✓      \-
  Auto-Fix                      \-        ✓\*         ✓\*        \-      \-
  Manager Health                \-         \-          \-         ✓     ✓\*
  Approvals / CAB               \-        ✓\*           ✓         ✓     ✓\*
  Major Incident                \-        ✓\*           ✓         ✓      \-
  Forecast                      \-         \-           ✓         ✓     ✓\*
  Semantic Search              ✓\*          ✓           ✓         ✓       ✓
  APM Alerts                    \-          ✓           ✓         ✓       ✓
  Tenant Admin                  \-         \-          \-        \-       ✓
  Device Registry              ✓\*        ✓\*         ✓\*       ✓\*       ✓
  Knowledge Base                 ✓          ✓           ✓         ✓       ✓

`*` Access/action availability depends on the permissions defined by the
SRS/RBAC rules.

------------------------------------------------------------------------

# 14. Navigation Map

``` text
AUTHENTICATION
      │
      ▼
ROLE-BASED DASHBOARD
      │
      ├── REQUESTER
      │     ├── Home
      │     ├── Service Catalog
      │     ├── Create Case
      │     ├── My Tickets
      │     ├── Ticket Detail
      │     ├── Knowledge Base
      │     └── Notifications
      │
      ├── OPERATOR
      │     ├── Queue
      │     ├── Case Workspace
      │     │     ├── AI Copilot
      │     │     ├── Timeline
      │     │     ├── Knowledge
      │     │     └── Auto-Fix
      │     ├── Problems / KEDB
      │     ├── Knowledge Base
      │     └── Notifications
      │
      ├── TEAM LEAD
      │     ├── Queue
      │     ├── Workload
      │     ├── Problems
      │     ├── Approvals
      │     ├── Major Incidents
      │     └── Knowledge
      │
      ├── MANAGER
      │     ├── Operational Health
      │     ├── Analytics
      │     ├── Approvals / CAB
      │     ├── Major Incidents
      │     ├── Forecasts
      │     └── Notifications
      │
      └── ADMIN
            ├── Organizations
            ├── Teams / Users
            ├── Security Policies
            ├── Alert Rules
            ├── Device Registry
            └── Audit Logs
```

------------------------------------------------------------------------

# 15. Stitch Generation Order

Do not generate all screens as one large Stitch request.

Use this order.

## Batch 1 --- Design Foundation

1.  Authentication
2.  Global Dashboard Shell
3.  Navigation
4.  Common components
5.  Case cards
6.  Status/Priority/SLA components

## Batch 2 --- Requester

7.  Requester Home
8.  Case Intake
9.  Ticket Detail / Live Chat

## Batch 3 --- Operator

10. Operator Queue
11. Operator Workspace
12. AI Copilot
13. Problem / KEDB
14. Auto-Fix Console

## Batch 4 --- Leadership

15. Manager Operational Health
16. Approvals / CAB
17. Major Incident War Room
18. Predictive Workload

## Batch 5 --- Enterprise

19. Semantic Search
20. APM Alerts
21. Multi-Tenant Administration
22. Device Registry

## Batch 6 --- Knowledge

23. Knowledge Base
24. AI Knowledge Article Drafting

------------------------------------------------------------------------

# 16. Stitch Prompt Rules

Every Stitch prompt should reference the following constraints:

``` text
Use the AI Helpdesk design system.

Style:
- Clean enterprise-grade interface
- Minimalist
- Material 3
- Linear / Stripe / Vercel-inspired visual hierarchy
- Professional IT operations product
- White surfaces
- Subtle borders
- Subtle elevation
- Generous whitespace
- Strong typography hierarchy

Do not:
- Use excessive gradients
- Use flashy AI effects
- Use a generic chatbot layout
- Overuse purple
- Create unnecessary decorative elements

AI should appear as contextual workflow assistance:
- Summary cards
- Recommendation panels
- Confidence indicators
- Risk indicators
- Suggested actions
```

------------------------------------------------------------------------

# 17. Stitch-to-Flutter Handoff Rules

Stitch designs are visual references and must not override the PRD/SRS
business rules.

During implementation:

``` text
PRD
 ↓
SRS
 ↓
UI Screen Map
 ↓
Stitch Design
 ↓
Flutter Implementation
```

If a Stitch design conflicts with the PRD or SRS:

**PRD/SRS business rules take precedence.**

If a visual detail is not specified:

**Use the established frontend design system.**

------------------------------------------------------------------------

# 18. Implementation Principle

The UI must remain usable even when AI services are unavailable.

Core case functionality must not depend on AI.

The architecture should follow:

``` text
Case Data
    │
    ├── Human Workflow
    │
    ├── SLA Engine
    │
    ├── Notifications
    │
    ├── Audit Trail
    │
    └── AI Assistance
            │
            ▼
       Recommendation
            │
            ▼
       Human Decision
            │
            ▼
        Action
```

AI is an assistant to the IT service workflow, not the owner of the
workflow.

------------------------------------------------------------------------

# 19. Final Screen Inventory

    \# Screen                                    Module
  ---- ----------------------------------------- --------------------
     1 Authentication / Dual Sign-In             Shared
     2 Requester Home & Service Catalog          Requester
     3 Case Intake Wizard                        Requester
     4 Requester Ticket Detail & Live Chat       Requester
     5 Operator Queue & Workstation              Operator
     6 Operator Workspace & AI Copilot           Operator
     7 Problem Management & KEDB                 Operator / ITIL
     8 Controlled Auto-Fix Console               Operator / ITIL
     9 Manager Operational Health & Insights     Leadership
    10 Approvals & Change Management / CAB       Leadership / ITIL
    11 Major Incident Commander / War Room       Leadership / ITIL
    12 Predictive Workload & Capacity Forecast   Leadership
    13 Semantic Vector Search & NL Discovery     Enterprise
    14 Inbound APM Monitoring & Alerts           Enterprise
    15 Multi-Tenant SaaS & Security Policies     Enterprise
    16 Push Notification Device Registry         Enterprise
    17 Knowledge Base & AI Auto-Drafter          Shared / Knowledge

------------------------------------------------------------------------

# 20. Source-of-Truth Rule

This document is a UI mapping and implementation bridge.

It does **not** replace:

-   `AI_Helpdesk_PRD_Final(1).md` for product requirements
-   `AI_Helpdesk_SRS_Final(1).md` for technical/system requirements
-   `frontend_requirements.md` for detailed visual and Stitch
    requirements

When information differs:

1.  PRD defines product intent.
2.  SRS defines technical/system behavior.
3.  Frontend Requirements define visual/UI requirements.
4.  This UI Screen Map defines screen-level organization and
    implementation mapping.
