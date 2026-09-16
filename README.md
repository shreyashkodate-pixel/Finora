# AI IT Helpdesk

AI IT Helpdesk is a human-controlled, AI-assisted service desk system that streamlines IT issue reporting and service requests for employees, while equipping support staff with intelligent triage, continuous ticket summarization, missing-information detection, duplicate identification, smart routing recommendations, and 24/7 SLA monitoring.

---

## Architecture & Tech Stack

- **Client:** Single Flutter codebase targeting **Mobile** (Android/iOS), **Desktop** (macOS/Windows/Linux), and **Web**.
- **Backend API:** Python 3.11+ with **FastAPI** (`/api/v1`), using a layered architecture (`api/` → `services/` → `repositories/`).
- **Database & Storage:** **PostgreSQL** (managed via Supabase) with **SQLAlchemy** ORM, **Alembic** migrations, and **Supabase Storage** for ticket attachments.
- **AI Engine:** **Google Gemini API** (synchronous inline analysis, summaries, missing info, and draft replies) behind an internal `AIProvider` interface.
- **Background Sweeper:** In-process **APScheduler** ("The Sweep") monitoring 24/7 elapsed-time SLAs, risk scores, and escalation events.
- **Notifications:** In-app inbox and split email delivery (**Gmail SMTP** locally, **Brevo HTTP API** in staging/production).
- **Authentication:** Dual sign-in (**Argon2id + JWT** and **Google OAuth 2.0 / OIDC**) with strict Role-Based Access Control (**RBAC**) for Requesters, Operators, Team Leads, Managers, and Administrators.

---

## Repository Structure

```text
.
├── backend/            # FastAPI service (API, business logic, DB models, AI providers)
├── client/             # Multiplatform Flutter client (Mobile, Desktop, Web)
├── docs/               # Product Requirements Document (PRD) & Software Requirements Specification (SRS)
├── scripts/            # Database seed scripts and demo data utilities
├── .dockerignore       # Docker build exclusions
├── .env.example        # Environment variable template
├── .gitignore          # Git ignore rules
├── AGENTS.md           # Assistant development rules and Git workflow guidelines
└── README.md           # Project documentation and quickstart
```

---

## Branching & Workflow

This project adheres to the strict guidelines in [`AGENTS.md`](./AGENTS.md):
- **`main`**: Production and stable releases only. Never developed on directly.
- **`dev`**: Active integration trunk.
- **Topic branches (`feature/*`, `chore/*`)**: Created from `dev`, tested, and merged back into `dev`.

---

## Quickstart & Local Setup

### 1. Prerequisites
- Python 3.11+
- Flutter SDK (latest stable)
- Docker & Docker Compose (for local PostgreSQL)

### 2. Environment Configuration
Copy the sample environment file and configure your local settings:
```bash
cp .env.example .env
```

### 3. Start Database
```bash
docker-compose up -d
```

### 4. Setup Backend
```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn main:app --reload --port 8000
```

### 5. Setup Client
```bash
cd ../client
flutter pub get
flutter run -d chrome     # Or macos / windows / mobile emulator
```

---

## Testing

- **Backend tests:** `pytest` (from `backend/`)
- **Client tests:** `flutter test` (from `client/`)

---

## Documentation Links

- [Product Requirements Document (PRD)](./docs/AI_Helpdesk_PRD_Final.md)
- [Software Requirements Specification (SRS v3.3)](./docs/AI_Helpdesk_SRS_Final.md)
- [AI Coding Assistant Rules (AGENTS.md)](./AGENTS.md)
