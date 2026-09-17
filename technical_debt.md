# AI IT Helpdesk — Technical Debt & Future Roadmap

**Document Purpose**: Tracks architectural technical debt, known operational limits, and future roadmap milestones for the **AI IT Helpdesk**.  
**Current Status**: 
- **Phase 1 (Foundation & Core Workflows)**: Completed across 12 branches.
- **Phase 2 (ITIL & Production Hardening)**: Completed across 6 branches.
- **Phase 3 (Enterprise Backend & Intelligence)**: Completed across 5 branches.
- **Test Metrics**: 103/103 Backend Tests Passing (100%), 13/13 Flutter Tests Passing (100%).  
**Target Next Phase**: UI Screen Generation via Stitch & Cloud Deployment (Render/Supabase).  
**Last Updated**: September 17, 2026

---

## 1. Architectural Decisions & Operational Considerations

### 1.1 In-Memory Rate Limiter vs. External Brokers
* **Design Decision**: In accordance with user directives to avoid Redis dependencies, rate limiting uses pure Python in-memory sliding-window timestamp tracking (`InMemoryRateLimiter`).
* **Operational Characteristics**: Provides high performance (sub-millisecond overhead) with zero infrastructure dependencies. Perfect for single-instance or vertically scaled deployments.

### 1.2 Pessimistic Row-Level Locking for Sequences
* **Design Decision**: `case_sequences` table uses `select(...).with_for_update()` with dialect fallback to guarantee collision-free reference generation under high concurrent ticket intake.

### 1.3 SQLite DateTime Timezone Handling in Test Fixtures
* **Design Decision**: SQLite test sessions use UTC datetime normalization guards to maintain compatibility between PostgreSQL production and in-memory test suites.

### 1.4 Native Vector Embedding & Semantic Similarity
* **Design Decision**: Vector embeddings are normalized and computed via pure Python cosine similarity calculations, allowing semantic search to run reliably in local SQLite environments while remaining 100% compatible with PostgreSQL `pgvector`.

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

[x] Consolidated Branches 10–12: Multiplatform Flutter Client Foundation

========================= PHASE 2: COMPLETED =========================
[x] Branch 1: Problem Management, Change Management (CAB) & Major Incident Commander
[x] Branch 2: Controlled Auto-Fix Remediation & Sandbox Engine
[x] Branch 3: AI Knowledge Auto-Drafting & ReportLab PDF Generation
[x] Branch 4: Real-time WebSockets & Outbound Webhook Integrations (Slack/Teams)
[x] Branch 5: High-Concurrency Sequence Locking & Zero-Redis Rate Limiting
[x] Branch 6: Phase 2 Flutter Client Integration (ITIL Workspaces, War Room & Remediation UI)

========================= PHASE 3: COMPLETED =========================
[x] Branch 1: Semantic Vector Search & Natural Language Discovery Engine
[x] Branch 2: Inbound Monitoring & Alert Ingestion (Prometheus/Datadog/Sentry/CloudWatch)
[x] Branch 3: Predictive Workload, SLA Risk Scoring & Team Capacity Analytics
[x] Branch 4: Multi-Tenant Organization SaaS Governance & Security Policies
[x] Branch 5: Push Notification Subsystem & Device Token Registry (FCM/APNs/WebPush)

========================= FUTURE ROADMAP =========================
[ ] UI Screen Generation via Stitch
    ├── Stitch UI design for Semantic Search & NL Discovery View
    ├── Stitch UI design for Inbound Alerts & Monitoring Dashboard
    ├── Stitch UI design for Predictive Analytics & Workload Forecast Charts
    ├── Stitch UI design for Multi-Tenant Organization Management
    └── Stitch UI design for Device Push Notification Settings
[ ] Production Cloud Deployment & CI/CD
    ├── Multi-stage production Dockerfile and Render blueprint
    ├── GitHub Actions workflow for automated test runner and build checks
    └── Supabase Storage bucket production policy setup
```

---

## 3. Next Priorities

1. **Design UI Screens in Stitch**:
   - Utilize Stitch to generate visual components for the Phase 3 backend APIs (`/search`, `/integrations/alerts`, `/analytics`, `/admin/organizations`, `/notifications/devices`).
2. **Production Deployment**:
   - Execute production deployment to Render with managed PostgreSQL and Supabase Storage.
