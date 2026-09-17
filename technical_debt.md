# AI IT Helpdesk — Technical Debt & Future Roadmap

**Document Purpose**: Tracks architectural technical debt, known operational limits, and future roadmap milestones for the **AI IT Helpdesk**.  
**Current Status**: Branches 1–5 Completed and Verified (41/41 Passing Tests).  
**Target Next Milestone**: Branch 6 — In-App & Email Notifications via Gmail SMTP / Brevo HTTP (`feature/notifications-api`).  
**Last Updated**: September 17, 2026

---

## 1. Architectural & Code Technical Debt

### 1.1 In-Memory Rate Limiter vs. Distributed Redis Cache
* **Current State**: Sliding-window IP rate limiter (`core/rate_limit.py`) maintains request timestamp lists in Python process memory.
* **Technical Debt**: In a multi-worker production environment (e.g. multiple Uvicorn workers or horizontally scaled containers), rate limits are enforced independently per worker rather than globally across the cluster.
* **Target Solution**: Introduce a Redis-backed sliding-window rate limiter using Redis sorted sets (`ZADD` / `ZREMRANGEBYSCORE`) when scaling beyond a single web worker instance in Phase 2.

### 1.2 High-Concurrency Reference Number Sequencing
* **Current State**: `_generate_reference_number()` queries the maximum existing reference number for `<TYPE>-<YEAR>-%` within the active transaction to calculate `next_seq`.
* **Technical Debt**: Under extreme concurrent request bursts (tens of simultaneous case submissions per second), two transactions could read the same maximum reference number before committing, triggering a unique constraint collision on `reference_number`.
* **Target Solution**: Implement a dedicated `case_sequences` table with row-level locking (`SELECT ... FOR UPDATE`) or a native PostgreSQL sequence generator per year and type.

### 1.3 SQLite DateTime Timezone Stripping in Test Fixtures
* **Current State**: SQLite (`sqlite+aiosqlite`) stores datetimes as naive strings, stripping UTC offset information upon deserialization.
* **Technical Debt**: Service comparison logic required defensive `.replace(tzinfo=timezone.utc)` guards to prevent `TypeError: can't compare offset-naive and offset-aware datetimes` in tests.
* **Target Solution**: Configure a custom SQLAlchemy `TypeDecorator` for DateTime in test sessions to automatically enforce UTC `tzinfo` attachment on SQLite load, keeping service logic pure.

### 1.4 Native PostgreSQL Enum Migration Overhead
* **Current State**: Enums (`CaseStatus`, `CasePriority`, `UserRole`, etc.) are mapped to native PostgreSQL `ENUM` types via SQLAlchemy.
* **Technical Debt**: Adding new status states or roles in future phases requires custom Alembic migration scripts using raw DDL (`ALTER TYPE casestatus ADD VALUE 'NEW_STATUS';`), as standard autogenerate does not detect enum changes.
* **Target Solution**: Document explicit enum expansion migration patterns in Alembic templates.

---

## 2. Completed Milestones vs Future Roadmap

```
[x] Branch 1: Project Scaffolding & Shared Infrastructure
    ├── Docker Compose with PostgreSQL 16 Alpine
    ├── FastAPI foundation with health check and RFC error envelope
    └── Flutter multiplatform client structure and Idempotency API client

[x] Branch 2: Relational Database Models & Alembic Migrations
    ├── 15 SQLAlchemy ORM entities (Domain, AI, Governance)
    ├── PostgreSQL uuid-ossp and pg_trgm GIN search indexes
    └── Cyclical foreign key resolution (Team.lead_id vs User.team_id)

[x] Branch 3: Dual-Path Authentication, Google OAuth, & RBAC Engine
    ├── Argon2id password hashing and JWT token pair rotation
    ├── Google OAuth 2.0 PKCE / OIDC provider with conflict guard (409)
    ├── Refresh token single-use rotation and revocation tracking
    └── RBAC dependency factory (5 system roles)

[x] Branch 4: Case Lifecycle, State Machine, SLA & Audit API
    ├── Sequential reference generator (INC-YYYY-XXXXXX)
    ├── 24/7 wall-clock elapsed SLA engine (P1–P4)
    ├── Formal state machine validator with 7-day reopen window
    ├── Optimistic concurrency locking (version integer)
    ├── Strict message visibility masking (requester vs internal)
    └── Immutable append-only AuditLog tracking

[x] Branch 5: Evidence & File Uploads via Supabase Storage
    ├── MIME & magic-bytes file validation (jpg, png, webp, gif, pdf, docx, txt, log)
    ├── Size constraints (max 10MB per file, 50MB per case)
    ├── Server-generated UUID storage filenames
    └── Supabase Storage bucket integration with presigned URLs

[ ] Branch 6: Notification Subsystem
    ├── Local dev Gmail SMTP provider
    ├── Production Brevo HTTP API provider (Render outbound-SMTP bypass)
    └── Event triggers (Case created, assigned, SLA warning/breach, resolved)

[ ] Branch 7: Gemini AI Integration
    ├── Inline Case Triage & Category/Priority Suggestion
    ├── Living Case Summarization on new messages
    ├── Proactive Risk Assessment Scoring
    └── AI Communication Draft Assistant

[ ] Branch 8: Periodic SLA & Risk Sweep Engine
    ├── In-process APScheduler background sweep (every 5 mins)
    ├── Automated SLA breach detection and escalation triggering
    └── Render free-tier spin-down mitigation with uptime health pinger

[ ] Branch 9: Knowledge Base & Approval Workflows
    ├── Markdown Knowledge Article management and pg_trgm search
    └── Multi-tier approval requests for high-risk changes

[ ] Branches 10–12: Multiplatform Flutter Client
    ├── Clean Architecture (Presentation, Domain, Data)
    ├── Screen reader compatibility via Semantics widgets
    └── Responsive adaptive layout (Mobile, Tablet/Desktop, Web)
```

---

## 3. Next Milestone (Branch 6) Implementation Priorities

1. **Notification Provider Abstraction**: Implement `NotificationProvider` base interface with `GmailSmtpNotificationProvider` (local dev) and `BrevoNotificationProvider` (staging/production HTTP API over port 443).
2. **Event Dispatch Integration**: Hook notifications into case lifecycle events (case created, assigned, SLA warning/breach, resolved) per SRS §3.9 & §5.10.
3. **Resilient Non-Blocking Delivery**: Ensure email send failures are logged and retried without rolling back the underlying database transactions per SRS §7.7/§7.14.
