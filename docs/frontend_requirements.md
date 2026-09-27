# AI IT Helpdesk — Frontend & Stitch Screen Design Requirements

**Document Status:** Complete UI Design System & Screen Specification for Stitch Generation  
**Design Aesthetic:** Clean, Minimalist Enterprise Grade (Linear / Stripe / Vercel style) — functional, modern, crisp, and uncluttered. Avoid generic "AI-generated" gimmicks, glowing gradients, or cartoonish graphics.  
**Platform Target:** Flutter Multiplatform (Responsive Web, Desktop & Mobile)  
**Last Updated:** September 20, 2026  

---

## 1. Design System & Visual Style Guide

### 1.1 Aesthetic Philosophy
* **Minimalist & Professional:** Clean borders (`1px solid #E2E8F0`), flat surfaces, subtle 0–2dp elevation shadows, generous whitespace, and tight typographic hierarchy.
* **Functional AI Integration:** AI capabilities are presented as quiet, assistive inline components (clean summary cards, confidence meters, badge tags) rather than flashy chatbot overlays or purple sparkle gimmicks.
* **High Contrast & Accessible:** Strict WCAG 2.1 AA compliance with minimum 4.5:1 text-to-background contrast and 48x48 min touch targets.

### 1.2 Color Tokens

| Token Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| `primaryBlue` | `#1E40AF` | Deep Enterprise Blue — Primary brand, active tabs, primary action buttons |
| `primaryHover` | `#1D4ED8` | Hover / focus state for primary buttons |
| `backgroundLight` | `#F8FAFC` | App background (subtle warm slate) |
| `surfaceLight` | `#FFFFFF` | Card & modal background |
| `borderLight` | `#E2E8F0` | Subtle container borders and dividers |
| `textPrimary` | `#0F172A` | High-contrast headings and body text |
| `textSecondary` | `#64748B` | Timestamps, subtitles, helper text |
| `priorityP1` | `#DC2626` | Critical Priority (Crimson Red) |
| `priorityP2` | `#EA580C` | High Priority (Warm Amber/Orange) |
| `priorityP3` | `#2563EB` | Medium Priority (Royal Blue) |
| `priorityP4` | `#64748B` | Low Priority (Neutral Slate) |
| `statusResolved` | `#16A34A` | Success / Resolved / Compliant (Emerald Green) |
| `statusWarning` | `#D97706` | Approaching SLA / Warning state |
| `aiSubtleAccent` | `#6366F1` | Assistive AI badge / summary border (Indigo) |

---

## 2. Global Component Standards

1. **Top Navigation & Shell (`DashboardShell`):**
   * *Desktop/Web:* Clean left sidebar (`NavigationRail`) with icon + text label, user profile avatar at bottom, and active tab indicator (filled primary blue with rounded corners).
   * *Mobile:* Bottom `NavigationBar` with 3 to 4 core tabs and an overflow menu.
2. **Standard Data Card:**
   * White background (`#FFFFFF`), `1px` border (`#E2E8F0`), `8px` border radius, `16px` internal padding, no heavy drop shadows.
3. **Status & Priority Badges:**
   * Compact rounded pill (`4px` radius), soft tinted background (e.g. Red `#FEE2E2` with Dark Red text `#991B1B` for P1).
4. **SLA Countdown Timer Chip:**
   * Monospace font for time countdown (e.g., `02:45:10 remaining`), color shifts from Green -> Amber (at <20% remaining) -> Red (at breach).

---

## 3. Screen-by-Screen Specifications & Stitch Prompts

---

### Module A: Requester Self-Service Portal

#### Screen 1: Requester Home & Service Catalog
* **Purpose:** Clean, welcoming entry point for employees to search for help, view active tickets, or submit a request.
* **Key Components:**
  * Top greeting banner with minimal natural language search bar: *"Describe what you need help with..."*
  * 3 Quick Action Cards: *Report an Incident*, *Request Hardware/Software*, *Browse Knowledge Base*.
  * Active Tickets Section: Simple table/cards showing reference ID (`INC-2026-000142`), title, status pill (`IN PROGRESS`), and live SLA countdown badge.
* **Stitch Prompt Template:**
  > "Design a clean, minimalist enterprise self-service helpdesk home screen in light mode. At the top, a prominent search input with a clean search icon and text 'Describe what you need help with...'. Below it, three minimalist action cards in a row with subtle grey borders: 'Report an Incident' with an alert icon, 'Request Software/Hardware' with a laptop icon, and 'Knowledge Base' with a book icon. Below this, a section titled 'My Active Requests' containing a clean, borderless list of 2 tickets with ticket IDs like 'INC-2026-001042', a blue status pill 'In Progress', a priority badge, and a simple SLA countdown timer chip. Use a modern slate/white palette with deep blue accents."

---

#### Screen 2: Case Intake Wizard (Report Issue / Request Service)
* **Purpose:** Simple, non-technical submission form that collects necessary context without overwhelming the user.
* **Key Components:**
  * Segmented toggle: `Incident (Something is broken)` vs `Service Request (I need something)`.
  * Form fields: Title input, detailed description textarea, Urgency dropdown (`Low`, `Medium`, `High`, `Critical`).
  * Minimalist drag-and-drop attachment dropzone with file size indicator (Max 10MB).
  * Subtle assistive prompt: *"Suggested Articles"* drawer that appears on the right side if relevant knowledge exists.
* **Stitch Prompt Template:**
  > "Design a minimalist, uncluttered support ticket submission form. Top header 'Submit a Request'. Below the header, a sleek segmented control button to switch between 'Report an Issue' and 'Request a Service'. Clean form fields with 1px light grey borders: 'Summary' single-line input, 'Category' dropdown, and 'Details' multi-line text box. An attachment upload box with a dashed light grey border and cloud upload icon. A primary blue 'Submit Ticket' button at the bottom right. On the right side, an optional subtle side card showing 2 'Related Solutions' with link icons. Clean, accessible, Stripe-like typography."

---

#### Screen 3: Requester Ticket Detail & Live Chat
* **Purpose:** Timeline view where employees can read updates, reply to support staff, and confirm resolution.
* **Key Components:**
  * Header: Ticket ID (`INC-2026-000841`), Title, Priority Chip, Assigned Team, and SLA target progress bar.
  * Chat Stream: Clean conversation thread with messages from the user (right-aligned) and IT Operator (left-aligned with operator badge).
  * Bottom message reply bar with attachment clip icon and Send button.
  * Resolution Banner: Green confirmation banner displayed when status is `RESOLVED` with *"Confirm Resolution"* and *"Reopen Ticket"* buttons.
* **Stitch Prompt Template:**
  > "Design a clean, minimalist ticket tracking and communication screen for an employee. Header displays ticket reference 'INC-2026-000841', status pill 'In Progress', and a subtle elapsed SLA bar. Center is a clean chat stream with message bubbles: operator messages on the left with an IT badge and timestamp, user messages on the right. Below the chat is a clean text input bar with an attachment paperclip icon and a blue send button. Top notification banner shows 'Work in progress by L2 Network Team'."

---

### Module B: Operator Workstation (L1 / L2 Support)

#### Screen 4: Operator Queue & Workstation
* **Purpose:** Central workstation for support staff to manage unassigned and assigned tickets.
* **Key Components:**
  * Metric summary cards at top: `Assigned to Me (4)`, `Unassigned Queue (12)`, `Approaching SLA (2)`, `Breached (0)`.
  * Filter & search bar: Search by keyword/reference, filter by Priority (P1–P4), Status, or Team.
  * Ticket Table: Compact rows showing Priority pill, Reference ID, Title, Requester name, SLA timer (color-coded), and quick "Assign to Me" button.
* **Stitch Prompt Template:**
  > "Design an enterprise IT operator ticket queue dashboard. Top row features 4 minimalist metric stat cards with crisp numbers: 'Assigned to Me: 4', 'Unassigned: 12', 'At SLA Risk: 2' (amber text), and 'Breached: 0'. Below is a clean filter bar with a search input, status dropdown, and priority filter pills. Main section is a compact, high-density table with columns: Priority, Ticket ID, Subject, Requester, Time Remaining, and Action. Clean alternating row hover states, crisp typography, no clutter."

---

#### Screen 5: Split-View Operator Workspace & AI Copilot
* **Purpose:** Primary working interface for operators to diagnose issues, review AI assistance, and communicate.
* **Key Components:**
  * Left Panel (60%): Ticket details, tabbed message stream (`Public Requester Chat` vs `Internal Staff Notes`), and attachment browser.
  * Right Panel (40% - AI Copilot & Actions):
    * *Living Summary Card:* 3-bullet concise synopsis of current situation.
    * *AI Triage Recommendation:* Suggested category/priority with "Apply Recommendation" button.
    * *SLA Risk Meter:* Risk score (e.g. `Low (15%)`) with factors.
    * *Response Drafter Button:* Generates canned/contextual replies.
    * *Auto-Fix Action Launcher:* Dropdown to execute verified remediations.
* **Stitch Prompt Template:**
  > "Design a modern two-column IT support workspace. Left side (65% width) contains ticket header with status dropdown, P2 priority badge, and tabs for 'Public Chat' and 'Internal Notes (Staff Only)'. Message feed shows internal notes with a light amber background to prevent accidental public disclosure. Right side (35% width) is a clean sidebar with three stacked cards: 1) 'Living Summary' with 3 concise bullet points, 2) 'AI Triage Suggestion' with confidence percentage and a subtle 'Apply' button, and 3) 'Quick Remediation' dropdown with a blue 'Execute Dry-Run' button. Crisp, modern, minimalist SaaS interface."

---

#### Screen 6: Problem Management & Known Error Database (KEDB)
* **Purpose:** Manage root-cause investigations, link recurring incident tickets, and publish workarounds.
* **Key Components:**
  * Problem record header: `PRB-2026-000019`, Status (`INVESTIGATING`, `KNOWN_ERROR`, `RESOLVED`).
  * Linked Incidents list: Badges showing 5 recurring incidents linked to this root problem.
  * Root Cause analysis text editor + Permanent Workaround box.
  * "Publish to Knowledge Base" button.
* **Stitch Prompt Template:**
  > "Design a clean Problem Management & Root Cause workspace. Header has problem ID 'PRB-2026-000019', title 'VPN Gateway Authentication Timeout Loop', and status pill 'Known Error'. Main section contains three structured text panels: 'Root Cause Analysis', 'Temporary Workaround', and 'Permanent Solution'. A side panel lists 'Linked Incidents (5)' with clickable ticket pills. Top right has an action button 'Publish to KEDB'. Clean, structured layout with 1px slate borders."

---

#### Screen 7: Controlled Auto-Fix Action Console
* **Purpose:** Sandboxed panel for operators to safely execute whitelisted remediation actions.
* **Key Components:**
  * Action Selector: Dropdown with `Restart Print Spooler`, `Flush DNS & Renew DHCP`, `Unlock AD Account`, `Purge Proxy Cache`.
  * Pre-Flight Dry-Run section: Shows execution parameters and predicted impact.
  * Execution Terminal: Monospace dark terminal box (`#0F172A`) showing live stdout output and rollback status.
  * Action confirmation buttons: `Dry Run (Safe)` and `Execute Remediation`.
* **Stitch Prompt Template:**
  > "Design a minimalist IT remediation execution panel. Top dropdown allows selecting 'Action: Flush DNS & Renew Lease'. Below is a parameter input card. Center features an embedded dark console terminal with green monospace text displaying dry-run check logs and verification steps. Bottom right contains two buttons: a secondary outlined 'Pre-Flight Dry Run' and a primary blue 'Execute Auto-Fix'. Clean safety warnings, modern DevOps styling."

---

### Module C: Leadership, Approvals & Governance (Lead / Manager)

#### Screen 8: Manager Operational Health & Insights
* **Purpose:** Executive overview of team performance, SLA adherence, and AI operational briefings.
* **Key Components:**
  * High-level KPI cards: `SLA Compliance Rate (97.4%)`, `Avg Resolution Time (2.1 hrs)`, `Total Intake (148)`.
  * Plain-Language AI Briefing Card: *"Intake increased 14% today due to SSO migration in building B. 2 P1 incidents mitigated within SLA."*
  * Workload Distribution Chart: Clean bar chart showing active cases across L1, L2, Network, and Systems teams.
* **Stitch Prompt Template:**
  > "Design an executive IT operations dashboard. Top KPI row: 4 minimalist metric cards showing 'SLA Compliance: 97.4%', 'Avg Resolution: 2.1h', 'Open Backlog: 34', and 'First Contact Resolution: 82%'. Below is a clean highlight banner with an indigo left border containing a plain-language summary: 'Operational Briefing: Workload steady, network ticket volume normalized after morning patch.' Below are two clean, minimal charts: a daily intake bar chart and a team capacity utilization graph. Clean, refined executive feel."

---

#### Screen 9: Approvals & Change Management (CAB) Review Center
* **Purpose:** Review and authorize pending service requests and Change Requests (Standard, Normal, Emergency).
* **Key Components:**
  * Inbox tabs: `Pending Approvals (3)`, `Scheduled Changes (7)`, `Past Decisions`.
  * Change Request Card: Reference `CHG-2026-000084`, Change Type badge (`NORMAL`), Risk Level (`HIGH`), Scheduled Window, Rollback Plan preview.
  * Decision buttons: `Approve Change` (Green) and `Reject with Reason` (Red).
* **Stitch Prompt Template:**
  > "Design an IT Change Advisory Board (CAB) review screen. Left panel is a list of pending change requests with risk badges ('High Risk' in amber, 'Standard' in blue) and scheduled implementation dates. Right panel is the detail view showing 'Implementation Plan', 'Backout / Rollback Strategy', and 'Impacted Services'. Bottom actions contain 'Reject Request' (outlined red) and 'Approve Change' (solid green). Clean, high-governance enterprise design."

---

#### Screen 10: Major Incident Commander (War Room)
* **Purpose:** Mission-control interface for critical P1 outages.
* **Key Components:**
  * Emergency banner: Red header displaying `MAJOR INCIDENT ACTIVE`, elapsed outage duration timer (`00:48:12`), and Incident Commander avatar.
  * Direct action buttons: `Join Live Bridge (Audio/Video)` and `Draft Stakeholder Broadcast`.
  * Live Incident Timeline: Real-time chronological log of actions, mitigation steps, and milestone events.
* **Stitch Prompt Template:**
  > "Design a high-priority Major Incident War Room dashboard. Top emergency banner has a subtle dark red header with 'MAJOR INCIDENT: Core Database Cluster Latency Spike', an elapsed outage timer '00:42:15', and a primary button 'Join Incident Bridge'. Main area is split: left side is a real-time chronological event feed with timestamps, right side has 'Impacted Systems' status indicators and an 'Executive Summary Drafter' box. High-clarity, high-focus interface."

---

#### Screen 11: Predictive Workload & Capacity Forecast
* **Purpose:** View 7-day intake forecast and operator burnout risk indices.
* **Key Components:**
  * Forecast Line Chart: Predicted daily ticket volume over the next 7 days broken down by priority with confidence interval shading.
  * Team Capacity Heatmap: Matrix of operators and their current workload saturation (Green: <70%, Amber: 70–90%, Red: >90%).
  * Burnout Risk Alert: List of teams/operators experiencing sustained high volume with actionable rebalancing suggestions.
* **Stitch Prompt Template:**
  > "Design a predictive analytics and capacity forecasting dashboard for IT management. Top features a 7-day intake prediction line chart with a light grey confidence band and priority breakdowns. Bottom features a 'Team Capacity Utilization' table with operator names, active ticket counts, and a color-coded capacity meter bar (Green for normal, Amber for high load). Right side card shows 'Workload Rebalancing Recommendations'. Minimalist, clean data visualization."

---

### Module D: Enterprise Intelligence & System Administration

#### Screen 12: Semantic Vector Search & Natural Language Discovery
* **Purpose:** Natural language knowledge search across all past cases, solutions, and documentation with verifiable citations.
* **Key Components:**
  * Prominent NL search prompt: *"How do we resolve error 0x80070005 on Windows print spooler?"*
  * AI-Synthesized Answer Box: Concise, direct answer with clickable citation tags (e.g. `[Case #INC-2025-0819]`, `[Article #SOP-042]`).
  * Vector Similarity Result Cards: Ranked list of matching cases/articles with cosine similarity match scores (`94% Match`).
* **Stitch Prompt Template:**
  > "Design a minimalist natural language search and discovery screen for IT helpdesk. Large search input box at the top with placeholder 'Ask a question or search error codes...'. Below is an 'AI-Synthesized Answer' card with an indigo top accent, showing a direct concise solution and small grey citation pills '[INC-2025-0912]' and '[SOP-401]'. Below the answer card is a list of 'Similar Historical Cases & Articles' with match percentage chips ('96% match'), author, and resolution summary. Clean, modern, highly readable."

---

#### Screen 13: Inbound APM Monitoring & Alerts Live Feed
* **Purpose:** Live feed of incoming alerts from Prometheus, Datadog, Sentry, and AWS CloudWatch.
* **Key Components:**
  * Live feed with pulse indicator: Cards showing Source icon (Prometheus, Datadog, etc.), Severity tag (`CRITICAL`, `WARNING`), Alert title, and Payload snippet.
  * Deduplication tag: `Grouped 14 alerts into 1 Incident`.
  * Action button: `View Generated Ticket (INC-2026-000912)`.
* **Stitch Prompt Template:**
  > "Design an inbound APM monitoring alert feed dashboard. Top controls allow filtering by source ('Prometheus', 'Datadog', 'Sentry', 'AWS CloudWatch') and severity ('Critical', 'Warning', 'Info'). The main feed shows incoming alert cards with source icons, timestamps, severity badges, alert descriptions, and a link button 'View Generated Incident #INC-2026-000412'. Shows a 'Deduplicated: 8 events' badge on grouped alerts. Clean, modern observability interface."

---

#### Screen 14: Multi-Tenant SaaS & Security Policies Settings
* **Purpose:** System admin configuration for organization profiles, SLA tiers, and security policies.
* **Key Components:**
  * Organization Profile card: Org Name, Slug, SLA Tier selector (`Bronze`, `Silver`, `Gold`, `Platinum`).
  * Domain Whitelist input (e.g. `@company.com, @subsidiary.org`).
  * Data Retention Policy sliders: Case history retention (`365 days`), Auto-closure window (`7 days`).
  * Security switches: `Enforce MFA`, `IP Allowlist`.
* **Stitch Prompt Template:**
  > "Design an enterprise SaaS multi-tenant organization settings page. Sections include: 1) 'Organization Details' with Name, Slug, and SLA Tier dropdown (Platinum selected), 2) 'Email Domain Whitelist' tag input field, 3) 'Data Retention & Governance' with numerical slider inputs for 'Case Retention (Days)' and 'Auto-Closure Window', and 4) 'Security Policies' with toggle switches for 'Enforce MFA' and 'Restrict IP Ranges'. Clean, minimalist settings page layout with a solid blue 'Save Changes' button."

---

#### Screen 15: Push Notification Device Registry & Preferences
* **Purpose:** Manage push notification device tokens and test alerts.
* **Key Components:**
  * Registered Devices list: Cards for `Android (FCM)`, `iOS (APNs)`, `Web Browser (WebPush)` with last active timestamps.
  * Granular Alert Toggles: `P1 Critical Incidents (Instant Push)`, `SLA Deadline Warnings (<20% remaining)`, `CAB Approval Requests`.
  * Test Push Dispatcher: Input box with "Send Test Alert" button.
* **Stitch Prompt Template:**
  > "Design a clean notification preferences and device push settings screen. Top card displays 'Registered Devices' showing user's active phone ('Google Pixel 8 - Android FCM') with an active green dot and a trash icon. Below is 'Notification Preferences' with clean toggle switches for 'Critical P1 Outages', 'SLA Warnings', and 'Approval Requests'. Bottom card contains a 'Push Test Simulator' with a text field and a 'Dispatch Test Notification' button. Minimalist, uncluttered layout."

---

### Module E: Shared Utility Screens

#### Screen 16: Authentication & Dual Sign-In
* **Purpose:** Clean, accessible login screen with email/password and Google OAuth PKCE.
* **Key Components:**
  * Center card: App logo, "AI IT Helpdesk" title, subtitle "Sign in to your enterprise account".
  * "Sign in with Google" button with official Google icon.
  * Divider: *Or sign in with email*.
  * Email and Password fields, "Forgot Password" link, and solid blue "Sign In" button.
* **Stitch Prompt Template:**
  > "Design a clean, centered enterprise login screen. Clean white card with subtle grey border on a soft slate background. Top features a minimalist IT badge icon and title 'AI IT Helpdesk'. A prominent full-width white button with grey border 'Continue with Google' with Google icon. A subtle 'or continue with email' divider. Email and Password input fields with 1px borders, and a full-width deep blue 'Sign In' button. Minimalist, uncluttered, highly professional."

---

#### Screen 17: Knowledge Base Browser & AI Auto-Drafter
* **Purpose:** Searchable library of standard operating procedures (SOPs) and troubleshooting guides.
* **Key Components:**
  * Category sidebar: `Hardware`, `Network & VPN`, `Access & Accounts`, `Email & Software`.
  * Markdown article viewer: Clear headers, code blocks with copy button, step-by-step numbered lists.
  * AI Drafting Banner: For operators viewing resolved cases — *"Generate Knowledge Article Draft with Gemini"* button.
* **Stitch Prompt Template:**
  > "Design a clean documentation and knowledge base browser. Left sidebar lists categories with article counts: 'Network & VPN (12)', 'Software & Accounts (8)'. Center panel displays a Markdown article 'Configuring GlobalProtect VPN on macOS' with clean typography, code snippet box with a copy button, and a helpfulness rating ('Was this helpful? Yes / No'). Top action bar has a 'Draft New Article from Incident' button with an AI icon. Minimalist, GitBook-like aesthetic."
