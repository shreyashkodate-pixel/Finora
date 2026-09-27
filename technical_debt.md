# AI IT Helpdesk — Technical Debt & Future Roadmap

**Document Purpose**: Tracks architectural technical debt, known operational limits, and future roadmap milestones for the **AI IT Helpdesk** (FastAPI + PostgreSQL + Gemini AI + Flutter Multiplatform).  
**Current Status**: 
- **Backend Phases 1–3**: Fully complete and tested (118/118 unit tests, 29 Postman endpoints).
- **Frontend Phases 1–4E**: Complete across all ITIL, AI, Analytics, Governance, and Notification domains (141/141 widget tests).
- **Phase 4F (CI/CD & Production Build Verification)**: Complete (.github/workflows/ci.yml, Dockerfile startup script, Alembic head validation, Flutter Web release build).
- **Stitch Full UI Fidelity Implementation**: 100% Complete across all 27 Stitch design references (Requester Portal, Operator Workstation, Manager Insights, Knowledge SOP Hub, War Room, Approvals CAB, Semantic Search, Governance, Alerts, and Push Notifications).
- **Test Metrics**: **118/118 Backend Tests Passing (100%)**, **141/141 Flutter Client Tests Passing (100%)**, **0 Dart static analysis issues**, **Flutter Web release bundle verified**.  
- **Target Next Phase**: Ready for Production Deployment & Staging Operations.  
- **Last Updated**: September 22, 2026

---

## 1. Architectural Decisions & Operational Considerations

### 1.1 In-Memory Rate Limiter vs. External Brokers
* **Design Decision**: In accordance with user directives to avoid Redis dependencies, rate limiting uses pure Python in-memory sliding-window timestamp tracking (`InMemoryRateLimiter`).
* **Operational Characteristics**: Provides sub-millisecond latency overhead with zero infrastructure dependencies. Designed for vertically scaled instances.

### 1.2 Pessimistic Row-Level Sequence Locking
* **Design Decision**: `case_sequences` table uses `select(...).with_for_update()` to guarantee collision-free reference generation under high concurrent ticket intake.

### 1.3 Optimistic Concurrency vs. ACID Database Serialization
* **Case Operations**: Case mutations enforce optimistic version locking (`version: int`) returning `409 STALE_VERSION` on concurrent edits. The Flutter client displays an explicit refresh notice rather than silently overwriting changes.
* **Major Incidents & Problems**: ITIL escalation entities utilize ACID transactional isolation and database-level integrity without client-side version fields.

### 1.4 Internal Message Confidentiality & Masking
* **Security Boundary**: Requester sessions never receive messages where `visibility = internal_only`. Filtering is enforced strictly at the database query level on FastAPI routes, eliminating client-side exposure risks.

### 1.5 7-Day Reopen Enforcement Rule
* **Lifecycle Rule**: Reopening tickets is restricted to `resolved_at + 7 days`. Outside this window, the UI disables the reopen action, directing users to create a new ticket linked as related.

### 1.6 Native Vector Embedding & Semantic Similarity
* **Design Decision**: Vector embeddings are normalized and computed via cosine similarity calculations, allowing semantic search to run reliably in local SQLite environments while remaining 100% compatible with PostgreSQL `pgvector`.

### 1.7 Responsive Layout & RenderFlex Protection
* **Layout Invariant**: Desktop/tablet viewports ($\ge 900\text{px}$) utilize Master-Detail split panes; mobile viewports ($< 900\text{px}$) utilize stacked single-pane cards with `Wrap` containers and `Flexible` button text to guarantee zero `RenderFlex` overflow errors across arbitrary screen geometries.

### 1.8 Pure Stitch Design Enforcement & Zero Dark Theme Collision
* **Design Decision**: The Flutter client explicitly sets `themeMode: ThemeMode.light` and routes `darkTheme => lightTheme`. This prevents host OS dark mode settings (e.g. macOS Dark Mode) from inadvertently overriding enterprise canvas colors (`#F8F9FF` / `#F8FAFC`) with legacy dark navy scaffolds behind white Stitch cards.
* **Hardcoded Cleanliness**: `LoginScreen` text controllers initialize without default strings to comply strictly with Rule 6 ("Don't do anything hardcoded").

### 1.9 Multi-Domain Whitelisting & Seeded Role Isolation
* **Design Decision**: Organizations support multiple whitelisted domains (`finora.local`, `enterprise.com`, `acme.corp`, `example.com`, `ithelpdesk.com`) via `Organization.domain_whitelist`. All 5 system roles (`requester`, `operator`, `team_lead`, `manager`, `administrator`) are seeded with uniform, verified credentials across standard enterprise and test domains.

---

## 2. Completed Milestones vs Future Roadmap

```
========================= BACKEND MILESTONES: COMPLETED =========================
[x] Phase 1 Backend: Foundation, Dual Auth (Argon2id/Google OAuth), Case Lifecycle, SLA Engine
[x] Phase 2 Backend: Problem Management, Change CAB, Major Incidents, Controlled Auto-Fix, WebSockets
[x] Phase 3 Backend: Semantic Search, Inbound Monitoring Alerts, Predictive Analytics, Multi-Tenancy

========================= FRONTEND MILESTONES: COMPLETED =========================
[x] Phase 1: Flutter Foundation, Design System Tokens & Adaptive Application Shell (8 tests)
[x] Phase 2A: Requester Portal — Service Catalog, Ticket Creation & Requester Inbox (12 tests)
[x] Phase 2B: Operator Workstation — Triage, Living Summaries, SLA Timers & Internal Notes (16 tests)
[x] Phase 3A: Problem Management & Known Error Database (KEDB) (12 tests)
[x] Phase 3B: Change Management, CAB Review & Multi-Tier Approvals (17 tests)
[x] Phase 3C: Major Incident Management & Command Bridge War Room (17 tests)
[x] Phase 4A: Semantic Search & Natural-Language Discovery Engine UI (11 tests)
[x] Phase 4B: Inbound Monitoring Alerts & Incident Ingestion Dashboard (12 tests)
[x] Phase 4C: Predictive Analytics, Workload Forecasts & Capacity Dashboard (12 tests)
[x] Phase 4D: Multi-Tenant Organization SaaS Governance UI & Security Configuration (11 tests)
[x] Phase 4E: In-App Notification Center & Push Notification Preferences (13 tests)
[x] Phase 4F: CI/CD Pipeline & Production Build Verification (GitHub Actions, Docker, Alembic, Web Build)
[x] Stitch Full UI Fidelity: 27/27 Stitch Design References translated and verified (141 tests)

========================= FUTURE ROADMAP =========================
[ ] Production Kubernetes / Helm chart packaging
[ ] Multi-region active-active PostgreSQL streaming replication
[ ] Enterprise Single Sign-On (SAML 2.0 / Okta / Azure AD SCIM provisioning)
```

---

## 3. Security & Governance Status (Verified ✅)

1. **Inbound Webhook Verification Strategy**:
   - `POST /api/v1/integrations/alerts/inbound/{provider}` enforces constant-time signature/token validation (`hmac.compare_digest`) via `ALERT_WEBHOOK_SECRET` and provider-specific environment variables (`PROMETHEUS_WEBHOOK_SECRET`, `DATADOG_WEBHOOK_SECRET`, `SENTRY_WEBHOOK_SECRET`, `CLOUDWATCH_WEBHOOK_SECRET`).
   - Supports headers (`X-Webhook-Secret`, `Authorization: Bearer`, `X-Datadog-Webhook-Secret`, `X-Sentry-Token`, `X-CloudWatch-Secret`) and URL query tokens. Rejects unauthenticated requests with `401 WEBHOOK_UNAUTHORIZED`.
2. **Tenant Isolation & RBAC Boundaries**:
   - Inbound alerts, alert rules, and team assignments are strictly scoped to the caller's `organization_id`.
   - Cross-tenant alert acknowledgement and cross-tenant team targeting in rules are rejected with `403 FORBIDDEN`.
   - Requesters are blocked server-side (403) from all alert/rule endpoints; Operators can list/acknowledge alerts and list rules but cannot create rules (403); Team Leads, Managers, and Admins can create rules (201).
3. **Argon2id Password Security**:
   - Argon2id with recommended OWASP memory (64MB) and time cost parameters.
4. **Gemini DLP & Audit Scrubbing**:
   - PII scrubbing before sending contextual prompt data to Gemini 2.5 Flash.
