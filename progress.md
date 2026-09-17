# AI IT Helpdesk — Development Progress Report

**Document Purpose**: Official development progress, completed milestones, architectural decisions, and verification records for the **AI IT Helpdesk** (FastAPI + PostgreSQL + Gemini AI + Flutter Multiplatform).  
**Current Release Target**: Phase 1 Foundation & Core Workflows per PRD & SRS v3.3 — **COMPLETED**.  
**Last Updated**: September 17, 2026  
**Status**: All 12 Branches Completed (Backend Branches 1–9 + Consolidated Frontend Branches 10–12). 100% Passing Tests (75/75 Backend Unit Tests + Frontend Serialization/Logic Tests).

---

## 1. Project Overview & Guiding Principles

The AI IT Helpdesk is a production-grade enterprise service desk platform featuring deterministic business logic, strict role-based access control (RBAC), 24/7 elapsed wall-clock SLA tracking, optimistic concurrency locking, append-only audit logging, and human-in-the-loop AI assistance powered by Google Gemini.

### Core Architectural Principles
* **Environment-Driven Configuration**: 100% environment-variable driven configuration (`core/config.py` in backend, compile-time `--dart-define` with safe fallbacks in `client/lib/shared/config.dart`); zero hardcoded secrets or credentials; strict `.env` exclusion.
* **Dual-Path Authentication**: Full support for both Argon2id password authentication and Google OAuth 2.0 PKCE / OIDC sign-in with conflict-guarded account isolation (`409 ACCOUNT_COLLISION` on email match).
* **Strict Role-Based Access Control (RBAC)**: Enforced at the FastAPI layer and reflected across Flutter views (`Requester`, `Operator` [L1/L2], `Team Lead`, `Manager`, `Administrator`).
* **Message Visibility & Confidentiality**: Strict separation between `requester_visible` communications and `internal_only` operator notes; automatic server-side masking for requesters.
* **Deterministic Concurrency & Auditability**: Optimistic locking (`version` integer) on mutating case operations (`409 STALE_VERSION` on collision); immutable append-only `AuditLog` records.
* **24/7 Elapsed SLA Engine**: Wall-clock UTC elapsed time math without complex holiday/business-hour dependencies (P1: 15m/4h, P2: 1h/8h, P3: 4h/72h, P4: 24h/120h) with real-time countdowns on client.
* **Secure Evidence Storage**: Magic-bytes validation (jpg, png, webp, gif, pdf, docx, txt, log), 10MB file / 50MB case limits, server-generated UUID paths, and presigned access URLs.
* **Human-in-the-Loop AI Assistant**: Advisory-only triage categorization, continuous living summarization, escalation risk detection, and communication drafting powered by `gemini-2.5-flash` with prompt-injection defenses.
* **Zero-Worker Background Processing ("The Sweep")**: In-process APScheduler engine running every 5 minutes for SLA monitoring, proactive warning alerts, breach detection, and multi-tier escalation hierarchy without external queues.
* **WCAG 2.1 AA Accessibility & Adaptive Design**: Deep Enterprise Blue palette with minimum 4.5:1 text contrast, `Semantics` wrappers, 48x48 min touch targets, and responsive layouts across Mobile (`NavigationBar`), Tablet, and Desktop (`NavigationRail`).

---

## 2. Completed Milestones & Git Commits

| Commit Hash | Branch | Description |
| :--- | :--- | :--- |
| `7b7986d` | `main` | `chore(repo)`: initialize repository with documentation, config templates, and rules |
| `00b0d16` | `chore/project-scaffolding` | `chore(scaffolding)`: initialize directory structure, docker-compose, and service skeletons |
| `a2af541` | `chore/project-scaffolding` | `chore(scaffolding)`: add client shared directories and base api_client |
| `e476aaf` | `chore/project-scaffolding` | `chore(ignore)`: ignore macos finder duplicate files |
| `a642486` | `dev` | `chore`: merge branch 'chore/project-scaffolding' into dev |
| `d4c5872` | `feature/database-and-models` | `feat(db)`: implement sqlalchemy models, alembic migrations, and trigram search indexes |
| `98fdaea` | `dev` | `feat`: merge branch 'feature/database-and-models' into dev |
| `f557715` | `feature/auth-and-rbac` | `feat(auth)`: implement dual-path jwt auth, google oauth, and rbac dependencies |
| `fed13f9` | `feature/case-lifecycle-api` | `feat(cases)`: implement case lifecycle api, reference generator, and optimistic locking |
| `9f87745` | `dev` | `feat`: merge branch 'feature/auth-and-rbac' into dev |
| `fbaecd3` | `dev` | `feat`: merge branch 'feature/case-lifecycle-api' into dev |
| `033231b` | `dev` | `docs`: add progress.md and technical_debt.md tracking project status and roadmap |
| `3733318` | `feature/file-upload-api` | `feat(attachments)`: implement file upload api, magic-bytes validation, and storage providers |
| `3553af0` | `dev` | `feat`: merge branch 'feature/file-upload-api' into dev |
| `77158d0` | `feature/notifications-api` | `feat(notifications)`: implement in-app alerts, email providers, and lifecycle hooks |
| `7fc0b9b` | `feature/notifications-api` | `docs`: update progress.md and technical_debt.md for branch 6 completion |
| `90be88b` | `feature/gemini-ai-integration` | `feat(ai)`: integrate Gemini 2.5 Flash for triage, living summaries, risk, and drafts |
| `191ce39` | `feature/gemini-ai-integration` | `docs`: update progress.md and technical_debt.md for branch 7 completion |
| `e22bb90` | `feature/periodic-sweep-engine` | `feat(sweep)`: implement APScheduler sweep engine, SLA breach detection, and escalations |
| `e63a95e` | `feature/knowledge-base-and-approvals` | `feat(knowledge-approvals)`: implement knowledge base and multi-tier approval workflows |
| Pending | `feature/frontend` | `feat(frontend)`: implement multiplatform flutter client for auth, cases, ai, and approvals |

```
[x] Branch 1: Project Scaffolding & Shared Infrastructure
[x] Branch 2: Relational Database Models & Alembic Migrations
[x] Branch 3: Dual-Path Authentication, Google OAuth, & RBAC Engine
[x] Branch 4: Case Lifecycle, State Machine, SLA & Audit API
[x] Branch 5: Evidence & File Uploads via Supabase Storage
[x] Branch 6: In-App & Email Notifications (Gmail SMTP / Brevo HTTP)
[x] Branch 7: Gemini AI Integration (Triage, Summary, Risk, Drafts)
[x] Branch 8: Periodic SLA & Risk Sweep Engine (APScheduler)
[x] Branch 9: Knowledge Base & Approval Workflows
[x] Branch 10: Flutter Client Authentication & Navigation (Consolidated on feature/frontend)
[x] Branch 11: Flutter Client Case Management & Message Stream (Consolidated on feature/frontend)
[x] Branch 12: Flutter Client AI Assistance & Operations Dashboard (Consolidated on feature/frontend)
```

---

## 3. Implemented Modules & Features

### Branch 1 — Project Scaffolding & Infrastructure
* **Docker & Environment**: Root `docker-compose.yml` with PostgreSQL 16 Alpine container and persistent volume mounting.
* **Backend Skeleton**: `FastAPI` service with lifespan startup configuration validator (`core/config.py`), CORS origin whitelist, `/api/v1/health` connectivity probe, and RFC-compliant error envelope.
* **Client Skeleton**: Multiplatform Flutter application directory structure (`client/lib/`) with modular feature boundaries (`auth/`, `cases/`, `ai/`, `knowledge/`, `shared/`) and HTTP API client with `Idempotency-Key` headers.

### Branch 2 — Database Models & Alembic Migrations
* **15 SQLAlchemy ORM Entities**:
  * Core Domain: `User`, `Team`, `Case`, `CaseRelationship`, `Message`, `Attachment`, `SLA`.
  * AI & Automation: `AITriageResult`, `CaseSummary`, `CaseRiskAssessment`, `EscalationEvent`, `CommunicationDraft`.
  * Governance: `AuditLog` (append-only), `KnowledgeArticle`, `Approval`.
* **Alembic Migrations**:
  * Dynamic URL resolution in `backend/db/migrations/env.py`.
  * Migration `0001_initial_schema.py` creating all tables, foreign keys with `use_alter=True` resolution for cyclical user/team constraints, and PostgreSQL extensions (`uuid-ossp`, `pg_trgm` GIN search indexes).

### Branch 3 — Authentication & RBAC Engine
* **Cryptography & Tokens (`core/security.py`)**:
  * Argon2id password hashing via `argon2-cffi`.
  * HMAC-SHA256 JWT access tokens (15-min expiry) and refresh tokens (7–30 day expiry).
  * Secure SHA-256 token hashing for persisted session tracking.
  * Time-limited signed email verification tokens.
* **Rate Limiting (`core/rate_limit.py`)**:
  * Sliding-window IP rate limiter restricting auth attempts (10 req/min per IP).
* **Session Persistence (`models/auth.py`, `0002_add_refresh_tokens.py`)**:
  * `RefreshToken` table storing device metadata, IP address, expiration, and revocation timestamps.
* **Google OAuth 2.0 PKCE Provider (`providers/auth/google.py`)**:
  * Authorization code exchange supporting PKCE (mobile/desktop) and standard web redirect flows; token verification and Google user profile resolution.
* **Auth Service (`services/auth_service.py`)**:
  * Dual-path registration and login.
  * Account collision defense: returns `409 Conflict` (`ACCOUNT_COLLISION`) when Google OAuth attempts to sign in with an email already bound to a password account.
  * Refresh token rotation: single-use refresh tokens revoked immediately upon rotation (`TOKEN_REVOKED_OR_EXPIRED`).
  * Email verification token consumption.

### Branch 4 — Case Lifecycle, State Machine, SLA & Audit API
* **Sequential Reference Generator (`services/case_service.py`)**:
  * Transaction-safe sequential format: `INC-YYYY-XXXXXX` and `REQ-YYYY-XXXXXX`.
* **24/7 Wall-Clock Elapsed SLA Engine (`services/case_service.py`)**:
  * Pure wall-clock UTC targets based on priority (P1: 15m/4h, P2: 1h/8h, P3: 4h/72h, P4: 24h/120h).
* **Deterministic State Machine & Optimistic Locking**:
  * Formal transitions: `NEW` -> `ASSIGNED` -> `IN_PROGRESS` -> `RESOLVED` -> `CLOSED`.
  * Version concurrency increment (`version += 1`); returns `409 Conflict` (`STALE_VERSION`) on mismatch.
  * 7-day reopen window strictly enforced (`REOPEN_WINDOW_EXPIRED`).
* **Message Visibility & Segregation**:
  * `requester_visible` vs. `internal_only` notes. Server-side masking completely conceals internal notes from requesters.
* **Append-Only Audit Logging**:
  * Every mutation writes an immutable `AuditLog` row recording actor, action, previous state, and new state.

### Branch 5 — Evidence & File Uploads (Supabase Storage)
* **Magic-Bytes File Validation (`core/files.py`)**:
  * Inspects binary header bytes for allowed MIME types (jpg, png, webp, gif, pdf, docx, txt, log). Blocks extension spoofing.
* **Quota Management & Storage Providers**:
  * Max 10MB per file, 50MB per case.
  * `LocalStorageProvider` for development; `SupabaseStorageProvider` for cloud deployment.
  * Presigned download URLs with 15-minute expiration.

### Branch 6 — In-App & Email Notifications
* **Notification Engine (`services/notification_service.py`)**:
  * Dual-provider architecture: `GmailSMTPProvider` for local testing; `BrevoHTTPProvider` for cloud hosting (Render).
  * In-app notification feed with read/unread tracking and batch actions.
  * Event dispatch on case creation, assignment, resolution, SLA warnings, and breaches.

### Branch 7 — Gemini AI Integration
* **Gemini 2.5 Flash Client (`providers/ai/gemini.py`)**:
  * Structured JSON schema generation via official Google GenAI SDK.
  * Heuristic fallback provider for offline development and testing.
* **Triage & Living Summaries**:
  * Automated priority and category recommendation with confidence scoring.
  * Human-in-the-loop triage confirmation (`POST /api/v1/cases/{id}/ai/triage/apply`).
  * Continuous living summaries recomputed synchronously on new messages.
* **Risk Assessment & Response Drafter**:
  * Inactivity and SLA countdown risk scoring (Low, Medium, High, Critical).
  * Communication draft generator for info requests, progress updates, resolutions, and escalation summaries.

### Branch 8 — Periodic SLA & Risk Sweep Engine
* **In-Process Scheduler (`scheduler/manager.py`)**:
  * Embedded `APScheduler` running every 5 minutes (`SWEEP_INTERVAL_MINUTES=5`) without worker overhead.
  * Render free-tier keepalive self-health pinger.
* **The Sweep Service (`services/sweep_service.py`)**:
  * Proactive SLA warning alerts (at >= 80% elapsed window).
  * SLA breach detection with automated escalation creation.
  * Escalation promotion to Manager after 2 hours unacknowledged.
  * Operator manual escalation trigger.

### Branch 9 — Knowledge Base & Multi-Tier Approvals
* **Knowledge Base Engine (`services/knowledge_service.py`)**:
  * Markdown knowledge article authoring with `draft`, `published`, and `archived` states.
  * Full-text search and contextual recommendations matching active case tokens.
* **Approval Workflows (`services/approval_service.py`)**:
  * Business authorization requests on cases in `ASSIGNED` status.
  * State gating: `ASSIGNED` -> `AWAITING_APPROVAL` -> `ASSIGNED` upon decision.
  * Lead and Manager decision endpoints with audit recording.

### Consolidated Branches 10, 11 & 12 — Multiplatform Flutter Client (`feature/frontend`)
* **Shared Infrastructure & Enterprise Design System**:
  * `AppConfig`: 100% environment-driven configuration reading compile-time `--dart-define` parameters with zero hardcoded URLs/secrets.
  * `SessionStorage`: Secure token persistence wrapping `flutter_secure_storage` with resilient in-memory fallback for headless or restricted environments.
  * `ApiClient`: HTTP client injecting Bearer JWT tokens, RFC error envelope deserialization, auto-generated UUIDv4 `Idempotency-Key` headers, and transparent 401 token refresh rotation retry.
  * `AppColors` & `AppTheme`: Material 3 design system adhering to WCAG 2.1 AA standards (minimum 4.5:1 text contrast, Deep Enterprise Blue `#1E40AF` palette, semantic SLA colors).
  * `ResponsiveScaffold`: Adaptive layout supporting Mobile (`NavigationBar`), Tablet, and Desktop (`NavigationRail`).
  * `SlaTimerWidget`: Real-time wall-clock countdown timer with warning (<20% remaining) and breach states.
  * `AccessibleButton`: Accessibility wrapper providing semantic labels and 48x48 min touch targets.
* **Authentication & Navigation (Branch 10 Scope)**:
  * `UserModel`: Role parsing and capability getters (`isStaff`, `canApprove`, `isManagerOrAdmin`).
  * `AuthProvider`: Dual-path login, password registration, Google OAuth sign-in, session restore on launch, single-use refresh token rotation, and logout.
  * `LoginScreen` & `RegisterScreen`: Accessible forms with validation, error banners, and site/campus selection.
  * `AuthGate`: Global authentication state switcher routing between Login, Splash, and Dashboard.
* **Case Management & Message Stream (Branch 11 Scope)**:
  * `CaseModel`, `SLAModel`, `MessageModel`, `AttachmentModel`: Strong typing and full JSON serialization.
  * `CaseProvider`: Ticket listing, keyword search, status/priority filtering, intake submission, optimistic locking version management, message posting, and offline read-only caching.
  * `CaseListScreen`: Filterable ticket feed with real-time SLA countdown timers.
  * `CreateCaseDialog`: Validated intake form for Incidents and Service Requests.
  * `MessageStreamWidget`: Chat-style message feed with distinct visual segregation for internal notes vs. requester communications.
  * `AttachmentListWidget`: Evidence file browser with file type icons, size display, and download triggers.
  * `CaseDetailScreen`: Unified multi-tab workspace embedding Timeline, AI Copilot, Case Info, and Approvals.
* **AI Assistance, Approvals & Operations Dashboards (Branch 12 Scope)**:
  * `AIProvider`: Manages AI triage recommendations, Living Summaries, SLA risk assessments, and draft generation.
  * `AITriageCard`: Displays AI classification, confidence meter, and human-in-the-loop review button.
  * `LivingSummaryCard`: Collapsible living summary updating with latest developments.
  * `SLARiskCard`: Visual risk score meter with breakdown of aggravating factors.
  * `AIDraftDialog`: Context-aware response drafter supporting 4 draft types.
  * `ApprovalProvider` & `ApprovalPanelWidget`: Business authorization request workflow and decision buttons.
  * `PendingApprovalsScreen`: Unified inbox for Leads and Managers.
  * `KnowledgeBrowserScreen`: Searchable knowledge article library with Markdown rendering.
  * `RequesterHomeScreen`: Self-service portal with active ticket counters, quick submission, and knowledge search.
  * `OperatorWorkspaceScreen`: Workstation for L1/L2 operators with triage queues and active assignments.
  * `ManagerInsightsScreen`: Executive operational health dashboard with SLA compliance rates, backlog charts, and plain-language AI operational briefings.
  * `DashboardShell`: Role-aware responsive navigation shell adapting menus to user roles.

---

## 4. Test Suite & Build Verification

### Backend Verification (Python 3.14 + Pytest)
```text
============================= test session starts ==============================
rootdir: backend, configfile: pytest.ini
plugins: asyncio-1.4.0, anyio-4.15.1
collected 75 items

backend/tests/unit/test_ai.py ..........                                 [ 13%]
backend/tests/unit/test_attachments.py .........                         [ 25%]
backend/tests/unit/test_auth.py ...........                              [ 40%]
backend/tests/unit/test_cases.py ............                            [ 56%]
backend/tests/unit/test_health.py ..                                     [ 58%]
backend/tests/unit/test_knowledge_approvals.py ...........               [ 73%]
backend/tests/unit/test_models.py .......                                [ 82%]
backend/tests/unit/test_notifications.py ......                          [ 90%]
backend/tests/unit/test_sweep.py .......                                 [100%]

======================== 75 passed, 2 warnings in 5.87s ========================
```

### Client Models & Logic Verification (`client/test/models_test.dart`)
* Full test coverage for JSON serialization/deserialization:
  * `UserModel`: Requester, Staff, Approver, and Admin permissions.
  * `CaseModel` & `SLAModel`: Concurrency version, 24/7 SLA targets, breach states.
  * `MessageModel`: Visibility segregation (`requester` vs. `internal_only`).
  * `AITriageModel`: AI classification, confidence score, and reasoning.
  * `RiskAssessmentModel`: Risk score, severity levels, and aggravating factors.
  * `ApprovalModel`: Business authorization requests and decision tracking.
  * `KnowledgeArticleModel`: Article state and lifecycle.
