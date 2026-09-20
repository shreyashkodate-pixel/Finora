# AI IT Helpdesk — Product Requirements Document (PRD)

**Document Status:** Version 4.0 — Unified Enterprise Product Specification  
**Current Release Target:** Phase 1 Foundation, Phase 2 ITIL & Hardening, Phase 3 Enterprise Intelligence — **ALL COMPLETED**  
**Last Updated:** September 20, 2026  

---

## 1. Executive Summary

AI IT Helpdesk is an enterprise-grade, human-controlled, AI-assisted IT Service Management (ITSM) platform that empowers employees to report IT issues and request services in plain language, while providing IT support teams with intelligent triage, continuous living summaries, predictive workload forecasting, automated remediation, ITIL-aligned governance, and real-time operational oversight.

The system spans **three completed major product phases**:
* **Phase 1 (Foundation & Core Workflows):** Incident & Service Request lifecycle, dual-path authentication (Argon2id + Google OAuth 2.0 PKCE), 24/7 wall-clock SLA engine, Gemini 2.5 Flash AI copilot, APScheduler sweep engine, evidence storage, in-app/email notifications, and WCAG 2.1 AA multiplatform Flutter client.
* **Phase 2 (Governed ITIL & Production Hardening):** Problem Management with Known Error Database (KEDB), Change Advisory Board (CAB) workflows, Major Incident Commander (War Room), sandboxed Controlled Auto-Fix remediation, AI Knowledge Article Auto-Drafting, ReportLab PDF case export, real-time WebSockets, Slack/Teams webhooks, and row-level pessimistic sequence concurrency locking.
* **Phase 3 (Enterprise Backend & Intelligence):** Semantic Vector Search & Natural Language Discovery Engine, Inbound APM Monitoring Ingestion (Prometheus/Datadog/Sentry/CloudWatch), Predictive Workload & SLA Risk Analytics, Multi-Tenant SaaS Governance, and Push Notification Device Token Registry (FCM/APNs/WebPush).

The product operates around the core service loop:
> Report or Ingest → AI Triage & Semantic Matching → Assign Ownership & SLA Clock → Human Collaboration & Remediation → Approval / CAB Review → Resolution & Auto-Draft Knowledge → Learn & Forecast.

---

## 2. Vision, Problem, and Core Product Principles

### Vision
Deliver an intuitive, explainable, and accountable IT service desk that eliminates bureaucratic friction for employees while supercharging IT operations with deterministic ITIL workflows and human-governed artificial intelligence.

### Problems Solved
1. **Intake Friction & Terminology Barriers:** Requesters describe problems in natural language without needing to know internal IT routing or technical categories.
2. **Context Fragmentation & Operator Fatigue:** Living case summaries and context-aware response drafters eliminate the need to manually reconstruct ticket timelines.
3. **Unmitigated SLA Breaches:** Proactive 80% SLA countdown warnings and predictive risk scoring alert leads before breaches occur.
4. **Disjointed Incident & Problem Management:** Seamless linkage between recurring incidents, root-cause Problem records, and permanent KEDB solutions.
5. **High-Risk Change Failures:** Formal CAB approval workflows, rollout plans, and automated rollback strategies for system modifications.
6. **Repetitive Low-Risk Remediations:** Sandboxed auto-fix actions (service restarts, DNS flushes, account unlocks) resolve frequent issues safely under operator supervision.
7. **Multi-Tenant Data Leakage:** Strict tenant-level isolation, organization domain whitelisting, and retention policies prevent unauthorized data cross-contamination.

### Core Architectural & Product Principles
1. **The Case is King:** Reporting, communication, state transitions, and audit records function independently even if AI or external services are offline.
2. **Human-in-the-Loop Governance:** AI acts strictly as an advisor (L1 Assist); authorized operators, leads, and CAB members maintain sole authority over status changes, public communications, approvals, and high-impact actions.
3. **Environment-Driven Configuration:** 100% environment-variable driven (`core/config.py` in backend, compile-time `--dart-define` in frontend); zero hardcoded secrets or infrastructure dependencies.
4. **Deterministic Concurrency & Auditability:** Optimistic locking (`version` integer) on case records and pessimistic row-level locking (`SELECT ... FOR UPDATE` on `case_sequences`) prevent state collisions and duplicate reference generation.
5. **Privacy, RBAC & Message Visibility:** Strict separation between `requester_visible` communications and `internal_only` operator notes with automatic server-side masking.
6. **Zero-Redis In-Process Reliability:** Pure Python in-memory sliding-window rate limiting (`InMemoryRateLimiter`) and embedded `APScheduler` sweep processing guarantee enterprise throughput with zero external broker dependencies.

---

## 3. User Roles and Access Governance

The platform enforces strict Role-Based Access Control (RBAC) across 5 core operational roles:

| Role | Responsibilities & Capabilities |
| :--- | :--- |
| **Requester** | Submits and tracks own incidents and service requests; uploads attachments; chats on public messages; confirms or reopens resolved tickets within 7 days. |
| **Operator (L1/L2)** | Triages assigned tickets; adds internal notes; executes Controlled Auto-Fix actions; creates Problem links; triggers draft communications; requests approvals. |
| **Team Lead** | Manages team queue and workload distribution; acts as tier-1 approver; handles SLA escalations; reviews known error articles. |
| **Manager** | Cross-team operational oversight; overrides priorities; conducts Change Advisory Board (CAB) reviews; accesses predictive capacity and operational health dashboards. |
| **Administrator** | Manages organizations, teams, and user accounts; configures alert rules, tenant retention policies, and SLA targets; inspects append-only audit logs. |

---

## 4. Product Model & Domain Entities

### 4.1 Case Types
1. **Incident (`INC-YYYY-XXXXXX`):** Unplanned interruption or reduction in quality of an IT service.
2. **Service Request (`REQ-YYYY-XXXXXX`):** Formal request from a user for something to be provided (hardware, software, access).
3. **Problem (`PRB-YYYY-XXXXXX`):** Underlying cause of one or more recurring incidents. Includes root cause analysis, workarounds, and KEDB publication.
4. **Change Request (`CHG-YYYY-XXXXXX`):** Governed addition, modification, or removal of authorized services/infrastructure. Managed through CAB approval tiers (`Standard`, `Normal`, `Emergency`).
5. **Major Incident (`MAJ-YYYY-XXXXXX`):** High-urgency P1 incidents triggering War Room collaboration, dedicated timeline tracking, and executive incident commander oversight.

### 4.2 Deterministic Case Lifecycle

```
Draft -> New -> In Assessment -> Assigned / In Progress <-> Awaiting Approval / Requester
                                            |
                                            v
                               Resolved / Fulfilled -> (7-Day Window) -> Closed
                                            |
                                            v (If rejected/recurring)
                                         Reopened
```

---

## 5. Service Level Agreement (SLA) Matrix

The system tracks 24/7 elapsed wall-clock UTC time targets:

| Priority Level | First Response Target | Resolution Target | Warning Window (80%) | Auto-Escalation |
| :--- | :---: | :---: | :---: | :---: |
| **P1 — Critical** | 15 minutes | 4 hours | At 3h 12m elapsed | Lead at breach; Manager after 2h |
| **P2 — High** | 1 hour | 8 hours | At 6h 24m elapsed | Lead at breach; Manager after 2h |
| **P3 — Medium** | 4 hours | 72 hours | At 57h 36m elapsed | Lead at breach |
| **P4 — Low** | 24 hours | 120 hours | At 96h elapsed | Queue flag |

---

## 6. Comprehensive Product Capabilities

### 6.1 Authentication, Security & RBAC (Phase 1)
* **Dual-Path Sign-In:** Argon2id hashed password credentials with email verification; Google OAuth 2.0 PKCE / OIDC integration.
* **Account Collision Protection:** Rejects unauthorized OAuth linking if email is already bound to a password account (`409 ACCOUNT_COLLISION`).
* **Session Management:** HMAC-SHA256 JWT access tokens (15m expiry) and single-use rotating refresh tokens (7–30d expiry) tracked in `refresh_tokens`.
* **Zero-Redis Rate Limiting:** Sliding-window in-memory IP limiter (10 req/min on auth endpoints).

### 6.2 Evidence Storage & Notifications (Phase 1 & Phase 3)
* **Magic-Bytes File Validation:** Header byte inspection blocking extension spoofing for allowed MIME types (jpg, png, webp, gif, pdf, docx, txt, log). Max 10MB/file, 50MB/case.
* **Multi-Provider Email & Storage:** Local Gmail SMTP / Production Brevo HTTP email; Local disk / Production Supabase Storage bucket with 15-minute presigned access URLs.
* **Multi-Platform Push Notifications:** Device registry supporting Android FCM, iOS APNs, and WebPush tokens with priority alert routing.

### 6.3 Gemini 2.5 Flash AI Copilot Suite (Phase 1 & Phase 2)
* **Advisory AI Triage:** Classifies incoming cases into category and priority with confidence scoring and reasoning; applied only via human confirmation (`POST /ai/triage/apply`).
* **Continuous Living Summaries:** Synchronously updates plain-language summaries whenever new messages or updates occur.
* **Proactive SLA Risk Scoring:** Evaluates inactivity, remaining time, and communication tone to flag impending breach risk (Low, Medium, High, Critical).
* **AI Communication Drafter:** Drafts contextual replies for Information Requests, Status Updates, Resolutions, and Escalation Summaries.
* **AI Knowledge Article Auto-Drafting:** Synthesizes structured troubleshooting SOPs from resolved case histories and root-cause solutions.

### 6.4 Periodic Background Sweep Engine (Phase 1)
* **Embedded APScheduler:** In-process periodic sweep running every 5 minutes (`SWEEP_INTERVAL_MINUTES=5`).
* **Automated Escalation:** Proactively emits 80% SLA warnings; flags breaches; promotes unacknowledged escalations to Managers after 2 hours.
* **Cloud Keepalive:** Self-health pinger preventing cloud container cold-starts on free-tier hosting (Render).

### 6.5 Governed ITIL Modules (Phase 2)
* **Problem Management & KEDB:** Groups related incidents under a Problem record, documents known errors, records permanent workarounds, and publishes to knowledge base.
* **Change Management (CAB):** Multi-tier change authorization with risk impact assessments, scheduled maintenance windows, implementation steps, and rollback plans.
* **Major Incident Commander:** War Room mode for critical outages with dedicated real-time incident timeline and executive stakeholder briefings.
* **Controlled Auto-Fix Sandbox:** Safe execution of whitelisted remediation scripts (`service_restart`, `dns_flush`, `account_unlock`, `cache_clear`) with pre-flight dry-run and automatic rollback upon failure.
* **ReportLab PDF Reporting:** Generates formal, publication-ready PDF case dossiers and executive post-incident reviews.
* **Real-time WebSockets & Webhooks:** Instant timeline streaming to active browser sessions and event notifications to Slack and Microsoft Teams channels.

### 6.6 Enterprise Intelligence & SaaS Scale (Phase 3)
* **Semantic Vector Search & NL Discovery:** Embeds case and article text into vector space, performs cosine similarity searches, and synthesizes answers with exact citation references.
* **Inbound APM Alert Ingestion:** Ingests monitoring webhooks from Prometheus, Datadog, Sentry, and AWS CloudWatch; automatically deduplicates alerts and creates P1/P2 incidents.
* **Predictive Workload & Capacity Analytics:** Forecasts 7-day intake volume, calculates team backlog throughput, and flags operator burnout risks based on workload saturation.
* **Multi-Tenant SaaS Governance:** Supports multi-tenant organization boundaries, custom domain whitelisting, SLA tier quotas, and configurable data retention policies.

---

## 7. Multiplatform Flutter User Experience

* **Design System:** Material 3 with WCAG 2.1 AA accessibility (minimum 4.5:1 text contrast, Deep Enterprise Blue `#1E40AF`, 48x48 min touch targets).
* **Adaptive Form Factors:** Single codebase supporting Mobile (`NavigationBar`), Tablet, and Desktop (`NavigationRail`).
* **Role-Specific Dashboards:**
  * *Requester Portal:* Ticket submission wizard, real-time status tracker, self-service knowledge search.
  * *Operator Workstation:* Triage queue, real-time SLA countdown timers, split-view case timeline (requester vs internal notes), AI Copilot drawer, and Auto-Fix panel.
  * *Lead & Manager Command Center:* Multi-tier approval inbox, CAB change scheduler, War Room commander, team capacity heatmaps, and predictive analytics charts.

---

## 8. Success Metrics & Verification

* **Backend Test Suite:** 103 / 103 unit tests passing (100% coverage across all 14 service domains).
* **Flutter Test Suite:** 13 / 13 tests passing (100% JSON model serialization and UI logic).
* **API End-to-End Suite:** 30 / 30 Postman/Newman assertions passing.
* **Code Quality:** 0 Dart analyze warnings; 0 Python syntax/lint errors.

---

## 9. Phased Scope Matrix

```
========================= PHASE 1: COMPLETED =========================
[x] Branch 1: Scaffolding, Docker & Environment Architecture
[x] Branch 2: 15 SQLAlchemy Database Entities & Alembic Migrations
[x] Branch 3: Dual Auth (Argon2id + Google OAuth PKCE) & RBAC Engine
[x] Branch 4: Case Lifecycle, 24/7 SLA Engine & Concurrency Versioning
[x] Branch 5: Evidence File Uploads (Supabase Storage) & Magic Bytes
[x] Branch 6: Notification Subsystem (Gmail SMTP / Brevo HTTP)
[x] Branch 7: Gemini 2.5 Flash AI Copilot (Triage, Summary, Risk, Drafts)
[x] Branch 8: Periodic SLA & Risk Sweep Engine (APScheduler)
[x] Branch 9: Knowledge Base & Multi-Tier Approvals
[x] Consolidated Branches 10–12: Flutter Multiplatform Client Foundation

========================= PHASE 2: COMPLETED =========================
[x] Branch 1: Problem Management, KEDB, Change CAB & Major Incident War Room
[x] Branch 2: Controlled Auto-Fix Remediation & Sandbox Engine
[x] Branch 3: AI Knowledge Auto-Drafting & ReportLab PDF Generation
[x] Branch 4: Real-time WebSockets & Outbound Webhooks (Slack/Teams)
[x] Branch 5: Sequence Row-Level Locking & Zero-Redis Rate Limiter
[x] Branch 6: Phase 2 Flutter Client Integration (ITIL Workspaces)

========================= PHASE 3: COMPLETED =========================
[x] Branch 1: Semantic Vector Search & Natural Language Discovery Engine
[x] Branch 2: Inbound APM Monitoring Ingestion (Prometheus/Datadog/Sentry)
[x] Branch 3: Predictive Workload, SLA Risk Scoring & Team Capacity Analytics
[x] Branch 4: Multi-Tenant Organization SaaS Governance & Security Policies
[x] Branch 5: Push Notification Subsystem & Device Token Registry (FCM/APNs)

========================= FUTURE ROADMAP =========================
[ ] UI Screen Generation via Stitch (Visual Flutter screens for Phase 3 APIs)
[ ] Production Cloud Deployment & CI/CD (Render, Supabase Managed DB, GitHub Actions)
```
