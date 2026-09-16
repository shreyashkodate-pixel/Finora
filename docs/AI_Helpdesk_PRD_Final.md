# AI IT Helpdesk — Product Requirements Document

**Document status:** Revised product requirements document  
**Product scope:** Phase 1, with explicit Phase 2 and Future boundaries

## 1. Executive summary

AI IT Helpdesk is a human-controlled, AI-assisted service desk that helps people report IT issues and request IT services, while helping support teams understand, prioritize, assign, communicate about, and resolve the work.

Phase 1 delivers a complete experience for two case types: **Incidents** (something is not working as expected) and **Service Requests** (a defined IT need). It combines straightforward case management with practical AI assistance, clear service targets, role-specific workspaces, communication, attachments, basic knowledge, notifications, audit history, and operational reporting.

The product is designed around one simple operational loop:

> Report or request → understand the need → collect what is missing → assign accountable ownership → communicate and progress work → resolve or fulfill → confirm the outcome → learn from the record.

AI makes recommendations and prepares work; people remain accountable for decisions and consequential actions.

## 2. Vision, problem, and product principles

### Vision

Make IT support easier to ask for, easier to run, and easier to improve through clear service workflows and explainable, human-controlled AI.

### Problems to solve

- People often do not know the correct team, category, or information needed to get help.
- Support staff spend too much time reconstructing context from messages, attachments, and earlier cases.
- Incomplete requests and poor handoffs create rework, reassignment, missed expectations, and avoidable delays.
- Similar issues and proven answers are difficult to find at the moment they are needed.
- Leaders need a credible view of service performance, workload, risk, and recurring issues.
- Automation can become unsafe when it hides uncertainty or acts without human authority.

### Product principles

1. **The case comes first.** Reporting, communication, ownership, service targets, and history continue to work when AI is unavailable.
2. **Be clear about uncertainty.** The product distinguishes reported facts, available evidence, missing information, AI suggestions, and human decisions.
3. **People control meaningful decisions.** AI assists; authorized people approve, decide, and act.
4. **Maintain one trustworthy record.** The case timeline shows the meaningful events, messages, decisions, and outcomes without rewriting a person's original contribution.
5. **Respect access and privacy.** People only see cases and information they are allowed to see; the same rule applies to search, reports, notifications, exports, and AI assistance.
6. **Automate carefully.** Start with recommendations, reminders, and well-defined workflow support. Make automation understandable and reversible where possible.
7. **Improve under governance.** Feedback and outcomes can improve the service, but the product does not self-authorize, self-publish, or silently change records.

## 3. Goals and non-goals

### Goals

- Let employees submit an issue or request without needing to understand IT terminology or team structures.
- Give support teams an understandable, accountable workspace for triage, collaboration, resolution, and fulfillment.
- Reduce time to a meaningful first response, unnecessary reassignment, repeated questions, and missed service targets.
- Surface relevant prior cases, approved knowledge, missing information, service risk, and recommended next steps.
- Keep requesters informed in plain language through resolution or fulfillment.
- Provide leaders with role-appropriate, trustworthy operational insight.

### Phase 1 non-goals

- Major Incident, Problem, and Change management workflows.
- Autonomous remediation, access provisioning, or other consequential action.
- Broad infrastructure monitoring, a full configuration-management database, procurement, security operations, or capacity planning.
- Push notifications.
- PDF exports.
- Offline submission, messaging, assignment, or delayed action syncing.
- Multi-organization service management or natural-language discovery across all organizational content.

## 4. Users, roles, and access

Phase 1 fully supports the following working roles. Access is limited by role, team, relationship to the case, and the sensitivity of information.

| Role | Product responsibility in Phase 1 |
| --- | --- |
| **Requester** | Submits and follows their own cases, supplies information and attachments, receives updates, and can confirm or reopen an outcome where policy allows. |
| **Operator** | Assesses, owns, updates, communicates about, and resolves or fulfills permitted cases; uses AI recommendations as support. |
| **Team Lead** | Oversees a team’s work, balances assignment, manages escalations, and guides operational response within their authority. |
| **Manager** | Has cross-team operational oversight, can reassign and override priority within policy, and uses cross-team dashboards and operational insights. |
| **Administrator** | Manages people, teams, roles, categories, service targets, notification settings, and other product governance; can review audit history. |

Other business roles—such as Approver, Knowledge Owner, Service Owner, and Auditor—are represented at a minimal level in Phase 1 so the product can evolve consistently. They are not full Phase 1 operating roles.

Requesters never see internal notes. A user does not gain access to restricted case information merely because it appears in a search result, dashboard, notification, export, or AI suggestion.

## 5. Product model

### 5.1 The case

The **case** is the authoritative record of a support need. Every case includes a reference, requester, type, title and description, current status, accountable team or person, priority, service target, timeline, communications, internal notes, attachments, relevant links, and resolution or fulfillment outcome.

AI-generated material is visibly identified as a suggestion or draft. A user can review, edit, accept, or disregard it. It never replaces the requester’s original wording or a material human decision.

### 5.2 Phase 1 case types

| Case type | Purpose |
| --- | --- |
| **Incident** | Restore a service or device that is interrupted or performing below expectation. |
| **Service Request** | Fulfill a defined IT need, such as an approved catalog request or a structured service request. |

Cases may be linked to related cases, services, assets, knowledge articles, and attachments when that context is available and permitted. Linking does not merge records or erase their separate history.

### 5.3 Case lifecycle

The product supports a consistent lifecycle, while allowing clear labels appropriate to the organization.

| State | Meaning |
| --- | --- |
| **Draft** | A requester has started but not submitted a case. |
| **New** | The case has been submitted and awaits assessment. |
| **In Assessment** | Information, classification, priority, or ownership is being established. |
| **Assigned / In Progress** | An accountable person or team is actively progressing the work. |
| **Awaiting Requester** | Further requester information, confirmation, or action is needed. |
| **Awaiting Approval** | A required business authorization is pending. |
| **Pending / External Dependency** | Progress depends on an outside party, date, or condition. |
| **Resolved / Fulfilled** | Work is complete and the outcome has been communicated. |
| **Closed** | The confirmation window and closure policy are complete. |
| **Cancelled** | Work will not proceed; the reason remains on the record. |

Every meaningful transition identifies who acted and when, and captures a reason or evidence when needed. A reopened case is an explicit, auditable continuation; it does not erase the previous outcome.

## 6. End-to-end experience

1. A requester chooses **Report an Issue** or **Request a Service**, using plain language without needing to know the correct technical category.
2. The product gathers the original description, useful structured details, urgency or impact context, and permitted attachments. A requester can save a draft.
3. When it would help, AI asks a small set of relevant follow-up questions. Urgent submission is never blocked; uncertainty is recorded rather than guessed.
4. The requester receives a case reference, the current status, the expected next step, and a clear way to add information.
5. AI prepares a reviewable analysis: a concise summary, likely classification, missing information, related-case signals, suggested ownership, priority inputs, and a recommended next action.
6. An operator or authorized workflow verifies the case, establishes ownership, and keeps the requester informed.
7. The case workspace brings communication, internal notes, attachments, history, service-target health, related records, approved knowledge, and AI support together in context.
8. The team records a clear resolution or fulfillment outcome. The requester is notified and can confirm or reopen it within policy.

## 7. Functional product requirements

### 7.1 Sign-in and account access

Users can sign in with either a password-based account or Google sign-in.

- Password-based sign-up requires email verification before the account can fully participate in the service.
- Google sign-in creates a verified account without a separate email-verification step.
- The product clearly explains sign-in, verification, recovery, and access problems in plain language.
- Access follows least-privilege principles and is reviewed through the role and team model.

### 7.2 Intake, catalog, search, and attachments

- Offer guided, accessible forms and free-text entry for Incidents and Service Requests.
- Ask only for information that is needed; clearly identify required and optional fields.
- Support permitted attachments and show their relationship to the case.
- Provide keyword search and case-reference lookup across a user’s permitted cases, approved knowledge, available services, and relevant assets.
- Provide filters, sorting, and saved views for operators.
- Clearly handle no results, partial results, unavailable information, and restricted results without implying that restricted information does not exist.

### 7.3 Case workspace and collaboration

- Show the case status, owner, next action, priority, service-target health, requester impact, and recent activity at a glance.
- Support requester-visible communication and separate internal notes. The visibility of a message must be evident before it is posted.
- Keep an automatic timeline of important activity, including submissions, assignments, messages, changes in status, escalation, notifications, and resolution.
- Allow authorized users to add updates, attachments, links, and resolution details.
- Make the case usable even if AI recommendations, search, or notifications are temporarily unavailable.

### 7.4 Service targets and prioritization

Service targets use **24/7 elapsed time**, not business hours. The product shows the applicable response and resolution targets, remaining time, and clear warning or breach states.

| Priority | Initial response target | Resolution target |
| --- | ---: | ---: |
| **P1 — Critical** | 15 minutes | 4 hours |
| **P2 — High** | 1 hour | 8 hours |
| **P3 — Medium** | 4 hours | 72 hours |
| **P4 — Low** | 24 hours | 120 hours |

Priority remains an accountable human decision. AI can identify urgency indicators and recommend priority inputs, but it does not silently make a high-impact priority decision.

### 7.5 Notifications

Phase 1 provides **in-app and email notifications**. Notifications are timely, understandable, and permission-aware. They cover meaningful events such as submission confirmation, assignment, a request for information, status change, service-target warning or breach, escalation, resolution or fulfillment, and reopening where applicable.

Notification delivery must not prevent the underlying case action from succeeding. Push notifications are outside Phase 1.

### 7.6 Knowledge

Phase 1 includes a basic, manually authored knowledge base. Authorized people can create and maintain guidance, and users can find approved articles through search and contextual suggestions.

Knowledge is clearly distinguished from a case-specific AI suggestion. AI may point to relevant approved knowledge, but Phase 1 does not let AI publish knowledge on its own.

### 7.7 Exports

Authorized users can export permitted report and case-list data as **CSV** in Phase 1. The export respects the same access restrictions as the product. PDF export is Phase 2.

## 8. AI capabilities and human control

### 8.1 Phase 1 automation capabilities

Phase 1 includes these 11 AI-assisted or automated capabilities:

1. **AI case analysis** — interprets the submitted case and prepares a reviewable assessment.
2. **Continuous case summary** — maintains a concise, current summary as meaningful case activity occurs.
3. **Missing-information detection** — identifies useful unanswered questions or gaps.
4. **Related and duplicate detection** — identifies potentially similar cases for human review.
5. **Smart assignment recommendation** — suggests an appropriate team or operator based on available context.
6. **Service-target and risk detection** — highlights approaching targets, breaches, inactivity, dependencies, or other operational risk signals.
7. **Escalation automation** — raises configured alerts or escalation steps when defined risk or target conditions are met.
8. **AI-generated communication drafts** — drafts clear messages for requesters or internal teams.
9. **Automated notifications** — sends approved, event-based in-app and email notices.
10. **Automatic timeline and audit logging** — records material case and governance events.
11. **AI-powered operational insights** — identifies actionable patterns in workload, performance, recurring themes, risk, and opportunity.

### 8.2 How AI presents guidance

AI guidance is understandable and reviewable. It should state supporting factors, important gaps, and limits when helpful. It may be presented as high, moderate, low, or unavailable confidence rather than false precision.

- **High confidence:** present the recommendation with relevant supporting context; policy and human accountability still apply.
- **Moderate confidence:** identify uncertainty and invite review or clarification.
- **Low confidence:** avoid a definitive recommendation; ask focused questions or route to human assessment.
- **Unavailable:** state that assistance is unavailable and provide the normal non-AI path.

### 8.3 Human-control boundaries

In Phase 1, AI may analyze, summarize, identify gaps, recommend routing, flag risk, suggest related cases, draft communication, and support notifications and audit history.

AI must not autonomously:

- approve, reject, or bypass an approval;
- merge, delete, replace, close, or reopen a case;
- confirm a root cause;
- declare or end a Major Incident;
- authorize or implement a Change;
- execute a consequential action, including access, financial, destructive, high-impact, or out-of-policy action.

Authorized people retain responsibility for case decisions, external commitments, approvals, closure, and any action with material impact.

### 8.4 Automation levels

| Level | Meaning | Phase 1 use |
| --- | --- | --- |
| **Level 1: Assist** | AI recommends, explains, summarizes, or drafts. A person decides what to use. | Core Phase 1 AI behavior. |
| **Level 2: Guided workflow** | The product performs defined, policy-approved workflow support such as notifications, logging, warnings, and escalations. | Used for Phase 1 notifications, timeline/audit entries, service-target monitoring, and escalation. |
| **Level 3: Controlled Auto-Fix** | A tightly governed, low-risk corrective action can be performed under explicit policy and oversight. | Phase 2 only. |

## 9. Dashboards, reporting, and insight

Each Phase 1 role receives a dashboard tailored to its work:

- **Requester:** own open cases, recent updates, actions needed, and knowledge or service-request entry points.
- **Operator:** assigned work, unassigned work they can address, service-target risk, awaiting responses, and recommended priorities.
- **Team Lead:** team workload, ownership gaps, aging work, escalations, target health, and reassignment needs.
- **Manager:** cross-team workload, service-target performance, trends, recurring patterns, escalation themes, and operational insights.
- **Administrator:** user and team administration, operational configuration, notification health, and authorized audit visibility.

Reports and insights must separate observed operational facts from AI interpretation. They should support action, not replace accountable review. CSV export is available for permitted data.

## 10. Failure states, usability, accessibility, and reliability

### 10.1 Clear fallback behavior

The product communicates problems plainly and preserves the normal case path wherever possible.

| Situation | Required product behavior |
| --- | --- |
| AI assistance is unavailable | Case creation, updates, communication, and resolution continue. The product clearly says that AI analysis is unavailable. |
| Notification cannot be delivered | The underlying action still succeeds; the delivery issue is recorded and handled without misleading the user. |
| Search or related-case detection is unavailable | A case can still be submitted and worked; suggestions simply do not appear. |
| Access is restricted | Explain that the user does not have access without exposing restricted details. |
| Another user has updated the case | Show a clear prompt to refresh and review the latest information; never silently discard someone’s work. |
| Connection is lost | Show an explicit offline state. Previously loaded information remains available read-only where cached. |
| Empty or loading view | Explain what is happening and what the user can do next. |

### 10.2 Offline use

Phase 1 offline use is **read-only cached viewing** of previously loaded content. While offline, users cannot submit, send, assign, change, approve, resolve, or otherwise mutate a case. The product does not queue offline actions for later submission.

### 10.3 Usability and accessibility

- Use clear, non-technical language for requesters and explain status, urgency, and next steps.
- Make critical state, ownership, timing, and visibility understandable without relying on color alone.
- Support keyboard use, readable layouts, clear focus, meaningful labels, and accessible error messages.
- Avoid forcing a requester through a long diagnostic flow before they can report an urgent issue.
- Offer useful empty states, loading states, confirmation messages, and recoverable error paths.

### 10.4 Reliability expectations

- Preserve the case record and audit history through ordinary product failures.
- Avoid duplicate actions and silent overwrites.
- Make delay, missing information, service-target risk, and unavailable dependencies visible.
- Ensure core case handling remains useful when an optional capability is unavailable.

## 11. Privacy, security, and audit at the product level

- Require authenticated access and enforce role- and relationship-based visibility.
- Keep internal notes separate from requester-visible communications.
- Limit AI assistance to information the current user and workflow are permitted to use.
- Ask for only information needed to process a case; discourage passwords, secrets, and unnecessary sensitive material.
- Maintain a durable audit trail of material actions, including who acted, what changed, and when.
- Do not allow routine activity to silently erase case history or audit evidence.
- Keep exports, notifications, dashboards, search, and AI guidance within the user’s permitted information boundary.
- Support appropriate administrative governance of users, roles, service targets, categories, notifications, and policy settings.

Formal retention and deletion governance is Phase 2.

## 12. Phased scope

### Phase 1 — AI-assisted Incident and Service Request management

Phase 1 includes:

- Incident and Service Request lifecycle management.
- Password and Google sign-in, with password email verification and no extra verification for Google sign-in.
- Roles fully supported in daily work: Requester, Operator, Team Lead, Manager, and Administrator.
- Guided intake, attachments, communication, internal notes, search, and role-specific dashboards.
- Basic manually authored knowledge base.
- 24/7 elapsed-time service targets and risk/escalation support.
- All 11 listed automation capabilities, with clear human review and fallback behavior.
- In-app and email notifications.
- CSV export for permitted data.
- Read-only cached viewing while offline.

### Phase 2 — governed service-management expansion

Phase 2 adds:

- Major Incident workflows.
- Problem management, including known errors and workarounds.
- Change management with authorization, implementation governance, validation, and appropriate recovery planning.
- AI-assisted knowledge drafting, with human review and publication.
- Governed integrations with other approved business systems.
- Formal retention and deletion policies.
- PDF export.
- Level 3 Controlled Auto-Fix for explicitly approved, low-risk actions under defined oversight.

### Future scope

Future direction may include:

- Natural-language discovery across permitted operational information.
- Deeper integration with configuration, monitoring, procurement, security, and collaboration tools.
- Predictive risk, demand, and capacity analytics.
- Multi-organization service management.
- Expanded, governed orchestration beyond controlled auto-fix.

## 13. Representative user stories and flows

### Requester reports an issue

As a requester, I can describe that something is not working in my own words, add an attachment, answer helpful follow-up questions if I can, and submit immediately if the issue is urgent. I receive a case reference and understandable updates until the issue is resolved.

### Operator triages a new case

As an operator, I can see the requester’s original description alongside an AI summary, missing-information prompts, suggested assignment, related cases, and service-target risk. I decide the classification, ownership, priority, and next action, then communicate clearly with the requester.

### Team Lead manages risk

As a team lead, I can see work without clear ownership, cases approaching a target, cases waiting too long, and escalations. I can redistribute work and guide the team while retaining an auditable history.

### Manager improves the service

As a manager, I can review cross-team performance and AI-supported operational insights to identify recurring issues, workload concerns, and improvement opportunities. I can act on the insight, but I do not treat an AI conclusion as an unverified fact.

### Administrator governs the product

As an administrator, I can manage users, teams, roles, categories, service targets, and notification settings, while preserving the audit history of important operating activity.

## 14. Success metrics

Phase 1 success is measured through outcomes that matter to requesters and service teams:

- Share of submitted cases that receive a meaningful first response within the applicable target.
- Time from submission to accountable assignment.
- Resolution or fulfillment time by priority and case type.
- Service-target warning and breach rate.
- Reassignment rate and repeated requests for the same information.
- Rate at which related cases or approved knowledge help resolve work faster.
- Requester satisfaction with clarity of progress and outcome.
- Operator assessment of AI suggestion usefulness, correctness, and ease of review.
- Percentage of material case actions represented in the timeline and audit history.
- Availability of the core case experience when AI, search, or notifications are unavailable.

## 15. Risks and guardrails

| Risk | Product guardrail |
| --- | --- |
| AI gives a plausible but wrong answer | Show uncertainty, supporting context, and gaps; retain human review and a non-AI path. |
| AI is treated as an authority | Keep consequential decisions and actions with authorized people. |
| Sensitive information reaches the wrong audience | Apply consistent access rules to views, search, notifications, exports, and AI context. |
| Automation creates unexpected impact | Limit Phase 1 automation to assistance and defined workflow support; reserve controlled auto-fix for Phase 2. |
| Users lose trust because a capability fails silently | Show clear fallback states and preserve the case workflow. |
| Reporting encourages superficial performance behavior | Pair metrics with context, trends, workload, and service-quality review. |
| Scope expands beyond a coherent first release | Treat Phase 1 boundaries as binding and use the phased roadmap for later capabilities. |

## 16. Final product definition

AI IT Helpdesk Phase 1 is a secure, understandable, AI-assisted IT support product for managing **Incidents and Service Requests** from first report through a recorded outcome. It gives requesters a simple path to help, gives teams one accountable case record and practical operational support, and gives leaders trustworthy visibility into service health.

Its AI is useful because it reduces repetitive effort, surfaces context and risk, and prepares clear next steps. Its human controls make it safe: people remain responsible for approvals, material decisions, case closure, and consequential action. The result is a focused foundation for reliable IT support today and governed service-management expansion tomorrow.
