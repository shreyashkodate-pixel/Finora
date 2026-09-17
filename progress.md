# AI IT Helpdesk — Development Progress Report

**Document Purpose**: Official development progress, completed milestones, architectural decisions, and verification records for the **AI IT Helpdesk** (FastAPI + PostgreSQL + Gemini AI + Flutter Multiplatform).  
**Current Release Target**: Phase 1 Foundation & Core Workflows per PRD & SRS v3.3.  
**Last Updated**: September 17, 2026  
**Status**: Branches 1, 2, 3, 4, and 5 Completed, 100% Passing Tests (41/41).

---

## 1. Project Overview & Guiding Principles

The AI IT Helpdesk is a production-grade enterprise service desk platform featuring deterministic business logic, strict role-based access control (RBAC), 24/7 elapsed wall-clock SLA tracking, optimistic concurrency locking, append-only audit logging, and human-in-the-loop AI assistance powered by Google Gemini.

### Core Architectural Principles
* **Environment-Driven Configuration**: 100% environment-variable driven configuration (`core/config.py`); zero hardcoded secrets or credentials; strict `.env` exclusion.
* **Dual-Path Authentication**: Full support for both Argon2id password authentication and Google OAuth 2.0 PKCE / OIDC sign-in with conflict-guarded account isolation (`409 ACCOUNT_COLLISION` on email match).
* **Strict Role-Based Access Control (RBAC)**: Enforced at the FastAPI layer across 5 system roles (`Requester`, `Operator`, `Team Lead`, `Manager`, `Administrator`).
* **Message Visibility & Confidentiality**: Strict separation between `requester_visible` communications and `internal_only` operator notes; automatic server-side masking for requesters.
* **Deterministic Concurrency & Auditability**: Optimistic locking (`version` integer) on mutating case operations (`409 STALE_VERSION` on collision); immutable append-only `AuditLog` records.
* **24/7 Elapsed SLA Engine**: Wall-clock UTC elapsed time math without complex holiday/business-hour dependencies (P1: 15m/4h, P2: 1h/8h, P3: 4h/72h, P4: 24h/120h).
* **Secure Evidence Storage**: Magic-bytes validation (jpg, png, webp, gif, pdf, docx, txt, log), 10MB file / 50MB case limits, server-generated UUID paths, and presigned access URLs.

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

```
[x] Branch 1: Project Scaffolding & Shared Infrastructure
[x] Branch 2: Relational Database Models & Alembic Migrations
[x] Branch 3: Dual-Path Authentication, Google OAuth, & RBAC Engine
[x] Branch 4: Case Lifecycle, State Machine, SLA & Audit API
[x] Branch 5: Evidence & File Uploads via Supabase Storage
[ ] Branch 6: In-App & Email Notifications (Gmail SMTP / Brevo HTTP)
[ ] Branch 7: Gemini AI Integration (Triage, Summary, Risk, Drafts)
[ ] Branch 8: Periodic SLA & Risk Sweep Engine (APScheduler)
[ ] Branch 9: Knowledge Base & Approval Workflows
[ ] Branch 10: Flutter Client Authentication & Navigation
[ ] Branch 11: Flutter Client Case Management & Message Stream
[ ] Branch 12: Flutter Client AI Assistance & Operations Dashboard
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
* **RBAC Dependencies (`api/deps.py`)**:
  * `get_current_user`: extracts and validates JWT access token.
  * `get_current_active_user`: enforces email verification outside local dev.
  * `require_roles(allowed_roles)`: enforces user role permissions (`403 PERMISSION_DENIED`).
* **Endpoints (`api/auth/routes.py`)**:
  * `/register`, `/login`, `/google`, `/refresh`, `/logout`, `/verify-email`, `/me`.

### Branch 4 — Case Lifecycle, SLA, State Machine & Audit API
* **Sequential Reference Generator (`services/case_service.py`)**:
  * Emits sequential reference numbers: `<TYPE>-<YEAR>-<sequential>` (e.g. `INC-2026-000001`, `REQ-2026-000001`).
* **24/7 Elapsed SLA Engine**:
  * Pure wall-clock UTC targets computed at creation and updated on priority change:
    * P1 (Critical): 15m response / 4h resolution
    * P2 (High): 1h response / 8h resolution
    * P3 (Medium): 4h response / 72h resolution
    * P4 (Low): 24h response / 120h resolution
  * Automatically records `responded_at` upon the first non-requester staff message.
* **Formal State Machine Engine**:
  * Validates transitions per SRS §6.1 (`Draft`, `New`, `InAssessment`, `Assigned`, `AwaitingRequester`, `AwaitingApproval`, `Resolved`, `Closed`, `Cancelled`).
  * Enforces 7-day reopen window for `Closed` cases (`400 REOPEN_WINDOW_EXPIRED`).
* **Optimistic Concurrency Locking**:
  * Requires caller `version` on all update and transition calls; returns `409 Conflict` (`STALE_VERSION`) on mismatch.
* **Message Visibility & Filtering**:
  * Requesters can only submit `requester_visible` notes; `internal_only` notes are strictly masked from requester responses.
* **Append-Only Audit Logging**:
  * Generates immutable `AuditLog` rows on creation, updates, transitions, messages, and linking.
* **Soft Deletion**:
  * Transitions status to `Cancelled` and sets `deleted_at = now()`.
* **Endpoints (`api/cases/routes.py`)**:
  * Full REST suite for cases, paginated listing with multi-field search, status transitions, messages, relationships, and audit history.

### Branch 5 — Evidence & File Uploads via Supabase Storage
* **File Validation & Magic Bytes (`core/file_validator.py`)**:
  * Validates binary headers against allowlist: `jpg`, `jpeg`, `png`, `webp`, `gif`, `pdf`, `docx`, `txt`, `log`.
  * Categorically rejects executable binaries (ELF, Windows PE/MZ, Mach-O, RAR, 7z) and null bytes in text.
  * Enforces maximum 10MB per file and 50MB cumulative attachment quota per case per SRS §7.5.
* **Storage Provider Abstraction (`providers/storage/`)**:
  * `StorageProvider` abstract interface.
  * `SupabaseStorageProvider`: Async HTTP REST client for Supabase Storage bucket uploads, time-limited presigned URLs, and object deletion.
  * `LocalStorageProvider`: Local filesystem storage engine for offline dev and zero-network automated unit testing.
  * Dynamic provider factory `get_storage_provider()`.
* **Attachment Service (`services/attachment_service.py`)**:
  * Generates server-side UUID storage path (`cases/{case_id}/{uuid4}{ext}`).
  * RBAC and case isolation enforcement (Requesters limited to own open cases; blocked on closed/cancelled cases).
  * 24-hour in-memory idempotency deduplication cache on mutating upload requests.
  * Emits append-only `AuditLog` records for `ATTACHMENT_UPLOADED` and `ATTACHMENT_DELETED`.
* **Endpoints (`api/attachments/routes.py`)**:
  * `POST /cases/{case_id}/attachments`: Multipart file upload with `Idempotency-Key` header support.
  * `GET /cases/{case_id}/attachments`: List attachments for case.
  * `GET /cases/{case_id}/attachments/quota`: Real-time storage consumption metrics and remaining quota.
  * `GET /attachments/{attachment_id}`: Metadata lookup.
  * `GET /attachments/{attachment_id}/download`: Presigned download link generator with configurable TTL.
  * `DELETE /attachments/{attachment_id}`: Deletes file from storage and database.

---

## 4. Test Suite & Build Verification

The test suite runs with `pytest` and `pytest-asyncio` using an in-memory SQLite database (`aiosqlite`) configured in `backend/tests/conftest.py`:

```text
============================= test session starts ==============================
platform darwin -- Python 3.14.4, pytest-9.1.1, pluggy-1.6.0 -- backend/.venv/bin/python3.14
rootdir: backend, configfile: pytest.ini
collected 41 items

tests/unit/test_attachments.py::test_upload_valid_png_attachment PASSED     [  2%]
tests/unit/test_attachments.py::test_upload_valid_pdf_and_docx PASSED      [  4%]
tests/unit/test_attachments.py::test_reject_disallowed_extension PASSED    [  7%]
tests/unit/test_attachments.py::test_reject_spoofed_extension PASSED       [  9%]
tests/unit/test_attachments.py::test_reject_file_exceeding_10mb PASSED     [ 12%]
tests/unit/test_attachments.py::test_case_quota_and_50mb_limit PASSED      [ 14%]
tests/unit/test_attachments.py::test_requester_isolation_and_staff_access PASSED [ 17%]
tests/unit/test_attachments.py::test_download_and_delete_attachment PASSED [ 19%]
tests/unit/test_attachments.py::test_idempotent_attachment_upload PASSED   [ 21%]
tests/unit/test_auth.py::test_password_registration_success PASSED          [ 24%]
tests/unit/test_auth.py::test_password_registration_short_password_rejected PASSED [ 26%]
tests/unit/test_auth.py::test_duplicate_registration_returns_409 PASSED     [ 29%]
tests/unit/test_auth.py::test_password_login_success PASSED                 [ 31%]
tests/unit/test_auth.py::test_password_login_wrong_password PASSED          [ 34%]
tests/unit/test_auth.py::test_refresh_token_rotation PASSED                 [ 36%]
tests/unit/test_auth.py::test_google_oauth_signup_and_account_collision PASSED [ 39%]
tests/unit/test_auth.py::test_verify_email_flow PASSED                      [ 41%]
tests/unit/test_auth.py::test_get_current_user_profile PASSED               [ 43%]
tests/unit/test_auth.py::test_require_roles_enforcement PASSED              [ 46%]
tests/unit/test_auth.py::test_unverified_email_blocked_in_production PASSED [ 48%]
tests/unit/test_cases.py::test_create_case_and_reference_number PASSED      [ 51%]
tests/unit/test_cases.py::test_sequential_reference_numbers PASSED          [ 53%]
tests/unit/test_cases.py::test_list_cases_requester_isolation PASSED        [ 56%]
tests/unit/test_cases.py::test_get_case_access_control PASSED               [ 58%]
tests/unit/test_cases.py::test_optimistic_locking_collision PASSED          [ 60%]
tests/unit/test_cases.py::test_case_state_transitions PASSED                [ 63%]
tests/unit/test_cases.py::test_invalid_state_transition_rejected PASSED     [ 65%]
tests/unit/test_cases.py::test_reopen_window_expired PASSED                 [ 68%]
tests/unit/test_cases.py::test_message_visibility_filtering PASSED          [ 70%]
tests/unit/test_cases.py::test_case_soft_delete PASSED                      [ 73%]
tests/unit/test_cases.py::test_case_relationships PASSED                    [ 75%]
tests/unit/test_cases.py::test_audit_logs_recorded PASSED                   [ 78%]
tests/unit/test_health.py::test_health_check_returns_ok PASSED              [ 80%]
tests/unit/test_health.py::test_root_endpoint PASSED                        [ 82%]
tests/unit/test_models.py::test_user_model_defaults_and_oauth PASSED        [ 85%]
tests/unit/test_models.py::test_case_model_defaults_and_optimistic_locking PASSED [ 87%]
tests/unit/test_models.py::test_sla_model_24_7_fields PASSED                [ 90%]
tests/unit/test_models.py::test_ai_triage_result_confidence_level PASSED    [ 92%]
tests/unit/test_models.py::test_case_risk_assessment_signals PASSED         [ 95%]
tests/unit/test_models.py::test_audit_log_system_actor_nullable PASSED      [ 97%]
tests/unit/test_message_visibility_control PASSED                           [100%]

======================== 41 passed, 1 warning in 2.78s =========================
```
