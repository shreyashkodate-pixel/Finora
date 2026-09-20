# AI IT Helpdesk — Software Requirements Specification (SRS)

**Version:** 4.0 — Unified Enterprise Specification  
**Status:** Completed and Verified across Phase 1, Phase 2, and Phase 3 Builds  
**Build Target:** FastAPI (Python 3.14) + PostgreSQL (Supabase / Local Docker) + Google Gemini 2.5 Flash + Flutter Multiplatform  
**Last Updated:** September 20, 2026  

---

## 0. Executive Summary

This Software Requirements Specification (SRS) defines the complete technical architecture, data model, API endpoints, business logic, security constraints, and operational invariants for the **AI IT Helpdesk** across all three delivered phases:

* **Phase 1 (Foundation & Core Workflows):** Dual-Path Authentication (Argon2id + Google OAuth 2.0 PKCE), 24/7 Wall-Clock Elapsed SLA Engine, Optimistic Concurrency Locking, Supabase Storage Evidence Management, Notification Engine (Gmail SMTP / Brevo HTTP), Gemini 2.5 Flash AI Copilot (Triage, Living Summaries, Risk, Drafts), APScheduler Sweep Engine, Markdown Knowledge Base & Multi-Tier Approvals, and Multiplatform Flutter Client with WCAG 2.1 AA Deep Enterprise Blue Theming.
* **Phase 2 (ITIL Suite & Production Hardening):** Problem Management with Known Error Database (KEDB), Change Advisory Board (CAB) workflows, Major Incident Commander (War Room), Sandboxed Controlled Auto-Fix Remediation Engine, AI Knowledge Article Auto-Drafting, ReportLab PDF Case Dossier Generation, Real-Time WebSockets & Outbound Webhooks (Slack/Teams), and Row-Level Pessimistic Concurrency Locking on Sequence Counters.
* **Phase 3 (Enterprise Intelligence & SaaS Scale):** Semantic Vector Search & Natural Language Discovery Engine, Inbound APM Monitoring Alert Ingestion (Prometheus/Datadog/Sentry/CloudWatch), Predictive Workload & SLA Risk Analytics, Multi-Tenant SaaS Governance & Security Policies, and Push Notification Subsystem (FCM/APNs/WebPush).

---

## 1. System Architecture & Invariants

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Unified Multiplatform Client                         │
│             (Flutter Mobile, Desktop & Web Targets)                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTPS + WSS (JWT Bearer Token)
                                    v
┌────────────────────────────────────────────────────────────────────────┐
│                         FastAPI Gateway Layer                          │
│   • CORS Origin Whitelist               • In-Memory Sliding Limiter    │
│   • RBAC Dependency Factory             • RFC-Compliant Error Envelope │
└─────────┬─────────────────────────┬──────────────────────────┬─────────┘
          │                         │                          │
          v                         v                          v
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│ Core Domain &    │      │  ITIL & Auto-Fix │      │  Intelligence &  │
│ SLA Engine       │      │  Remediation     │      │  Predictive APM  │
│ (Cases/Msgs/Auth)│      │ (Prb/Chg/Maj/Fix)│      │ (Search/Alrts/ML)│
└─────────┬────────┘      └─────────┬────────┘      └─────────┬────────┘
          │                         │                          │
          v                         v                          v
┌────────────────────────────────────────────────────────────────────────┐
│                     PostgreSQL 16 Storage Layer                        │
│   • 34 SQLAlchemy ORM Entities          • pgvector Cosine Embeddings   │
│   • Row-Level Sequence Locking          • Append-Only Audit Logging    │
│   • Local Docker OR Supabase Cloud      • pg_trgm GIN Search Indexes   │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Core Invariants & Architecture Rules
1. **Environment-Driven Configuration:** 100% environment-variable driven (`core/config.py`). Zero hardcoded secrets, connection strings, or third-party credentials.
2. **Dual-Environment Database & Storage:**
   * *Local Development:* Local Docker PostgreSQL 16 + Local disk storage (`uploads/`).
   * *Production:* Supabase Managed PostgreSQL + Supabase Storage bucket (`attachments`) with 15-minute presigned URLs.
3. **Zero-Redis In-Process Reliability:** Pure Python in-memory sliding-window rate limiting (`InMemoryRateLimiter`) and embedded `APScheduler` sweep processing guarantee enterprise throughput with zero external broker dependencies.
4. **Deterministic Concurrency:**
   * *Optimistic Locking:* `version` integer on `Case` mutations returning `409 STALE_VERSION` upon conflict.
   * *Pessimistic Locking:* `case_sequences` table updated with `SELECT ... FOR UPDATE` to eliminate race conditions in ticket number allocation (`INC-YYYY-XXXXXX`).
5. **Message Visibility & Confidentiality:** Server-side masking completely conceals `internal_only` notes from requesters while exposing them to operators.
6. **Human-in-the-Loop AI Boundary:** Gemini AI provides advisory triage, living summaries, risk alerts, and communication drafts; it never mutates case status or authorizes changes without explicit human operator confirmation.

---

## 2. Complete Relational Database Schema (34 Entities)

### 2.1 Core Identity & RBAC
1. **`users`**: `id` (UUID PK), `email` (unique), `password_hash`, `full_name`, `role` (`REQUESTER`, `OPERATOR`, `TEAM_LEAD`, `MANAGER`, `ADMIN`), `team_id` (FK), `organization_id` (FK), `is_active`, `is_verified`, `created_at`.
2. **`teams`**: `id` (UUID PK), `name`, `description`, `lead_id` (FK), `organization_id` (FK), `created_at`.
3. **`refresh_tokens`**: `id` (UUID PK), `user_id` (FK), `token_hash` (unique), `device_info`, `ip_address`, `expires_at`, `is_revoked`, `created_at`.

### 2.2 Case Management & SLAs
4. **`cases`**: `id` (UUID PK), `reference_number` (unique), `title`, `description`, `case_type` (`INCIDENT`, `SERVICE_REQUEST`), `status` (`NEW`, `IN_ASSESSMENT`, `ASSIGNED`, `IN_PROGRESS`, `AWAITING_REQUESTER`, `AWAITING_APPROVAL`, `RESOLVED`, `CLOSED`, `REOPENED`), `priority` (`P1`, `P2`, `P3`, `P4`), `requester_id` (FK), `assigned_team_id` (FK), `assigned_operator_id` (FK), `organization_id` (FK), `version` (int), `resolved_at`, `closed_at`, `created_at`, `updated_at`.
5. **`slas`**: `id` (UUID PK), `case_id` (FK unique), `response_deadline`, `resolution_deadline`, `first_responded_at`, `is_response_breached`, `is_resolution_breached`, `created_at`.
6. **`case_sequences`**: `id` (int PK), `case_type` (str), `year` (int), `last_sequence` (int). Row-locked with `FOR UPDATE`.
7. **`messages`**: `id` (UUID PK), `case_id` (FK), `sender_id` (FK), `content`, `visibility` (`REQUESTER_VISIBLE`, `INTERNAL_ONLY`), `created_at`.
8. **`attachments`**: `id` (UUID PK), `case_id` (FK), `uploader_id` (FK), `file_name`, `file_size`, `mime_type`, `storage_path`, `created_at`.
9. **`case_relationships`**: `id` (UUID PK), `source_case_id` (FK), `target_case_id` (FK), `relationship_type` (`DUPLICATE_OF`, `CAUSED_BY`, `RELATED_TO`), `created_at`.

### 2.3 AI Intelligence & Governance
10. **`ai_triage_results`**: `id` (UUID PK), `case_id` (FK), `predicted_category`, `suggested_priority`, `confidence_score`, `reasoning`, `is_applied`, `created_at`.
11. **`case_summaries`**: `id` (UUID PK), `case_id` (FK), `summary_text`, `version`, `created_at`.
12. **`case_risk_assessments`**: `id` (UUID PK), `case_id` (FK), `risk_score`, `risk_level` (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`), `factors`, `created_at`.
13. **`escalation_events`**: `id` (UUID PK), `case_id` (FK), `escalated_by` (FK), `reason`, `escalation_level` (`LEAD`, `MANAGER`), `is_acknowledged`, `created_at`.
14. **`communication_drafts`**: `id` (UUID PK), `case_id` (FK), `draft_type` (`INFO_REQUEST`, `STATUS_UPDATE`, `RESOLUTION`, `ESCALATION`), `content`, `created_at`.
15. **`semantic_embeddings`**: `id` (UUID PK), `source_type` (`CASE`, `KNOWLEDGE_ARTICLE`), `source_id` (UUID), `embedding_vector` (JSON / Vector), `content_hash`, `created_at`.
16. **`nl_query_logs`**: `id` (UUID PK), `user_id` (FK), `query_text`, `generated_answer`, `citations`, `created_at`.

### 2.4 Governance, Approvals & ITIL
17. **`audit_logs`**: `id` (UUID PK), `actor_id` (FK), `entity_type`, `entity_id`, `action`, `previous_state` (JSON), `new_state` (JSON), `ip_address`, `created_at`.
18. **`knowledge_articles`**: `id` (UUID PK), `title`, `content_markdown`, `category`, `status` (`DRAFT`, `PUBLISHED`, `ARCHIVED`), `author_id` (FK), `organization_id` (FK), `created_at`, `updated_at`.
19. **`approvals`**: `id` (UUID PK), `case_id` (FK), `approver_id` (FK), `approval_type`, `status` (`PENDING`, `APPROVED`, `REJECTED`), `decision_notes`, `decided_at`, `created_at`.
20. **`problems`**: `id` (UUID PK), `reference_number` (unique), `title`, `description`, `root_cause`, `workaround`, `status` (`OPEN`, `INVESTIGATING`, `KNOWN_ERROR`, `RESOLVED`, `CLOSED`), `owner_id` (FK), `created_at`.
21. **`known_errors`**: `id` (UUID PK), `problem_id` (FK unique), `error_code`, `symptoms`, `temporary_fix`, `permanent_solution`, `created_at`.
22. **`problem_case_links`**: `id` (UUID PK), `problem_id` (FK), `case_id` (FK), `created_at`.
23. **`change_requests`**: `id` (UUID PK), `reference_number` (unique), `title`, `description`, `change_type` (`STANDARD`, `NORMAL`, `EMERGENCY`), `risk_level` (`LOW`, `MEDIUM`, `HIGH`), `status` (`DRAFT`, `CAB_REVIEW`, `APPROVED`, `IMPLEMENTING`, `VALIDATING`, `CLOSED`, `REJECTED`), `implementation_plan`, `rollback_plan`, `scheduled_start`, `scheduled_end`, `requester_id` (FK), `created_at`.
24. **`major_incidents`**: `id` (UUID PK), `reference_number` (unique), `case_id` (FK unique), `commander_id` (FK), `status` (`DECLARED`, `WAR_ROOM_ACTIVE`, `MITIGATED`, `RESOLVED`, `PIR_PENDING`, `CLOSED`), `business_impact`, `bridge_url`, `created_at`.
25. **`major_incident_timelines`**: `id` (UUID PK), `major_incident_id` (FK), `actor_id` (FK), `event_summary`, `created_at`.
26. **`autofix_actions`**: `id` (UUID PK), `case_id` (FK), `operator_id` (FK), `action_type` (`SERVICE_RESTART`, `DNS_FLUSH`, `ACCOUNT_UNLOCK`, `CACHE_CLEAR`), `parameters` (JSON), `status` (`PENDING`, `EXECUTING`, `SUCCESS`, `FAILED`, `ROLLED_BACK`), `stdout_log`, `created_at`.

### 2.5 Monitoring, Analytics, Multi-Tenancy & Push Registry
27. **`inbound_alerts`**: `id` (UUID PK), `source` (`PROMETHEUS`, `DATADOG`, `SENTRY`, `CLOUDWATCH`), `external_alert_id`, `severity` (`INFO`, `WARNING`, `CRITICAL`), `payload` (JSON), `generated_case_id` (FK), `is_deduplicated`, `created_at`.
28. **`alert_rules`**: `id` (UUID PK), `source`, `match_pattern`, `auto_create_incident` (bool), `target_priority`, `assigned_team_id` (FK), `organization_id` (FK), `is_active`.
29. **`team_capacity_snapshots`**: `id` (UUID PK), `team_id` (FK), `active_ticket_count`, `throughput_rate`, `burnout_risk_score`, `snapshot_date`.
30. **`workload_forecast_snapshots`**: `id` (UUID PK), `forecast_date`, `predicted_intake_p1`, `predicted_intake_p2`, `predicted_intake_p3`, `predicted_intake_p4`, `confidence_interval`.
31. **`organizations`**: `id` (UUID PK), `name`, `slug` (unique), `domain_whitelist` (str), `sla_tier` (`BRONZE`, `SILVER`, `GOLD`, `PLATINUM`), `is_active`, `created_at`.
32. **`tenant_policies`**: `id` (UUID PK), `organization_id` (FK unique), `data_retention_days`, `auto_closure_days`, `require_mfa`, `allowed_ip_ranges`.
33. **`device_tokens`**: `id` (UUID PK), `user_id` (FK), `token` (unique), `platform` (`ANDROID_FCM`, `IOS_APNS`, `WEB_PUSH`), `device_name`, `last_active_at`, `created_at`.
34. **`notifications`**: `id` (UUID PK), `user_id` (FK), `title`, `body`, `event_type`, `related_case_id` (FK), `is_read`, `created_at`.

---

## 3. API Router Catalog (FastAPI v1)

| Route Prefix | Domain Focus | Key Endpoints | RBAC Policy |
| :--- | :--- | :--- | :--- |
| `/api/v1/auth` | Identity & Tokens | `/register`, `/login`, `/google`, `/refresh`, `/me` | Public / Authenticated |
| `/api/v1/cases` | Case Lifecycle & SLA | `POST /`, `GET /`, `GET /{id}`, `PATCH /{id}/status`, `POST /{id}/messages` | Requester / Staff |
| `/api/v1/attachments` | Evidence Files | `POST /upload`, `GET /{id}/download` | Authenticated |
| `/api/v1/ai` | Gemini Copilot | `POST /triage`, `POST /triage/apply`, `GET /summary`, `GET /risk`, `POST /draft` | Operator+ |
| `/api/v1/sweep` | Background Sweeper | `POST /run`, `GET /escalations` | System / Operator+ |
| `/api/v1/knowledge` | Knowledge Base | `GET /`, `POST /`, `GET /{id}`, `POST /ai/draft-from-case` | Authenticated / Staff |
| `/api/v1/approvals` | Multi-Tier Approvals | `GET /pending`, `POST /{id}/decision` | Lead / Manager / Admin |
| `/api/v1/itil` | Problem, CAB & War Room | `/problems`, `/changes`, `/major-incidents` | Operator / Lead / Manager |
| `/api/v1/autofix` | Controlled Auto-Fix | `POST /dry-run`, `POST /execute` | Operator+ |
| `/api/v1/reports` | Export Dossiers | `GET /pdf/{case_id}`, `GET /csv` | Operator+ |
| `/api/v1/realtime` | WebSockets & Integrations | `WS /ws/{case_id}`, `POST /webhooks/slack` | Authenticated / System |
| `/api/v1/search` | Vector & NL Discovery | `POST /semantic`, `POST /nl-query` | Authenticated |
| `/api/v1/integrations/alerts` | Inbound APM Monitoring | `POST /prometheus`, `POST /datadog`, `POST /sentry` | Authenticated / Webhook HMAC |
| `/api/v1/analytics` | Capacity & Forecasting | `GET /workload-forecast`, `GET /team-capacity`, `GET /burnout-risk` | Manager / Admin |
| `/api/v1/admin/organizations` | SaaS Governance | `GET /`, `POST /`, `PUT /{id}/policies` | Admin Only |
| `/api/v1/notifications/devices` | Push Device Registry | `POST /register`, `DELETE /{token}`, `POST /test` | Authenticated |

---

## 4. Non-Functional Requirements & Performance SLAs

1. **API Response Latency:** Sub-50ms 95th-percentile response time for transactional case reads and writes.
2. **AI Timeout & Resilience:** Gemini API requests timeout gracefully at 15s with fallback to deterministic heuristic analyzers.
3. **Concurrency Isolation:** Sequence generation guarantees 0 collisions under 100 simultaneous case submissions via `SELECT ... FOR UPDATE` row locks.
4. **Rate Limiting:** Auth routes enforce a sliding window of 10 requests per minute per IP address.
5. **Security & Input Sanitization:** Magic-bytes verification prevents malicious file execution; prompt-injection delimiters isolate untrusted requester text.
6. **Accessibility:** Client follows WCAG 2.1 AA standards with minimum 4.5:1 text contrast and 48x48 min touch targets.

---

## 5. Test Suite Verification Metrics

```text
============================= test session starts ==============================
rootdir: backend, configfile: pytest.ini
plugins: asyncio-1.4.0, anyio-4.15.1
collected 103 items

backend/tests/unit/test_ai.py ..........                                 [  9%]
backend/tests/unit/test_ai_knowledge_pdf.py ...                          [ 12%]
backend/tests/unit/test_attachments.py .........                         [ 21%]
backend/tests/unit/test_auth.py ...........                              [ 32%]
backend/tests/unit/test_autofix.py ..                                    [ 33%]
backend/tests/unit/test_cases.py ............                            [ 45%]
backend/tests/unit/test_concurrency_locking.py ..                        [ 47%]
backend/tests/unit/test_health.py ..                                     [ 49%]
backend/tests/unit/test_inbound_alerts.py ...                            [ 52%]
backend/tests/unit/test_knowledge_approvals.py ...........               [ 63%]
backend/tests/unit/test_models.py .......                                [ 69%]
backend/tests/unit/test_multi_tenancy.py ...                             [ 72%]
backend/tests/unit/test_notifications.py ......                          [ 78%]
backend/tests/unit/test_predictive_analytics.py ...                      [ 81%]
backend/tests/unit/test_problem_change_major.py ...                      [ 84%]
backend/tests/unit/test_push_notifications.py ...                        [ 87%]
backend/tests/unit/test_realtime_integrations.py ...                     [ 90%]
backend/tests/unit/test_semantic_search.py ...                           [ 93%]
backend/tests/unit/test_sweep.py .......                                 [100%]

======================= 103 passed, 4 warnings in 13.07s =======================
```
