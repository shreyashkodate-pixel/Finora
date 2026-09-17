# AI IT Helpdesk — Technical Debt & Future Roadmap

**Document Purpose**: Tracks architectural technical debt, known operational limits, and future roadmap milestones for the **AI IT Helpdesk**.  
**Current Status**: Phase 1 Foundation & Core Workflows Completed across All 12 Branches (75/75 Backend Tests Passing + Complete Multiplatform Flutter Client).  
**Target Next Phase**: Phase 2 — Production Hardening, Cloud Deployment, and Observability.  
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

### 1.5 Flutter Local Cache Persistence
* **Current State**: In-memory `Map<String, CaseModel>` cache with session storage fallback is used for offline ticket browsing.
* **Technical Debt**: If the application is completely killed and restarted in full offline mode without any previous network connectivity in that session, the cache resides in runtime memory.
* **Target Solution**: Integrate `hive_flutter` or `sqflite` for persistent local disk database caching in Phase 2 for field technicians operating in zero-connectivity environments.

---

## 2. Completed Milestones vs Future Roadmap

```
========================= PHASE 1: COMPLETED =========================
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

[x] Branch 6: Notification Subsystem
    ├── Local dev Gmail SMTP provider
    ├── Production Brevo HTTP API provider (Render outbound-SMTP bypass)
    └── Event triggers (Case created, assigned, SLA warning/breach, resolved)

[x] Branch 7: Gemini AI Integration
    ├── Inline Case Triage & Category/Priority Suggestion (Gemini 2.5 Flash)
    ├── Continuous Living Case Summarization on new messages
    ├── Proactive Risk Assessment & SLA signal scoring
    ├── AI Communication Draft Assistant with Human-in-the-Loop review
    └── Strict prompt-injection defenses (untrusted requester input)

[x] Branch 8: Periodic SLA & Risk Sweep Engine
    ├── In-process APScheduler background sweep (every 5 mins)
    ├── Automated SLA breach detection and escalation triggering
    ├── Proactive 80% SLA deadline warnings (in-app + email)
    ├── Managerial escalation promotion after 2 hours unacknowledged
    └── Render free-tier spin-down mitigation with keepalive health pinger

[x] Branch 9: Knowledge Base & Approval Workflows
    ├── Markdown Knowledge Article authoring, RBAC, and full-text search
    ├── Contextual knowledge suggestions from case tokens (SRS §5.14)
    ├── Multi-tier approval requests for high-risk changes & Service Requests
    └── Deterministic state gating (AWAITING_APPROVAL -> ASSIGNED) with version increment

[x] Consolidated Branches 10–12: Multiplatform Flutter Client (feature/frontend)
    ├── Branch 10: Dual Auth, Session Restore, Role Routing & WCAG 2.1 AA Themes
    ├── Branch 11: Real-time Case Workspace, Internal Notes Segregation & Attachments
    └── Branch 12: Gemini AI Copilot, Approvals Inbox, Role Dashboards & Metrics

[x] Postman API Collection & Automated Newman Test Suite
    ├── 29 endpoints across 8 modular folders (Health, Auth, Cases, Messages, AI, Approvals, KB, Sweep)
    ├── Parameterized environment configuration with zero-hardcoding
    └── Automated CLI execution via Newman (30/30 assertions passing, 0 regressions)

==================== PHASE 2: PRODUCTION HARDENING ====================
[ ] Cloud Infrastructure & CI/CD Pipeline
    ├── GitHub Actions workflows for automated linting, test suites, and Docker builds
    ├── Production deployment to Render (FastAPI web service + PostgreSQL managed DB)
    └── Supabase Storage bucket production policy setup
[ ] Distributed State & Caching
    ├── Redis cluster integration for distributed sliding-window rate limiting
    └── Redis cache for high-traffic Knowledge Base queries
[ ] Advanced Real-time Streaming
    ├── WebSocket event bus for instant timeline updates without manual polling
    └── WebRTC / Live agent presence indicators
[ ] Native Platform Integrations
    ├── Android & iOS push notifications via Firebase Cloud Messaging (FCM)
    └── Native biometric authentication (FaceID / Fingerprint) unlock
```

---

## 3. Phase 2 Recommended Next Priorities

1. **Production Docker Deployment**:
   * Create production multi-stage `Dockerfile` and `render.yaml` infrastructure blueprint.
2. **CI/CD Automation**:
   * Setup `.github/workflows/test.yml` running pytest, static analysis, and security scanning on PRs.
3. **Persistent Offline Storage**:
   * Migrate Flutter client memory cache to `hive_flutter` for persistent offline case management.
