import asyncio
import sys
from pathlib import Path
from datetime import datetime, timezone, timedelta
import uuid

# Add backend directory to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))

from sqlalchemy import select
from core.security import hash_password
from db.session import AsyncSessionLocal
from models.user import User, Team
from models.organization import Organization, TenantPolicy
from models.case import Case
from models.sla import SLA
from models.message import Message
from models.knowledge import KnowledgeArticle
from models.problem_change import Problem, ChangeRequest, MajorIncident
from models.enums import (
    UserRole,
    AuthProvider,
    AvailabilityStatus,
    CaseType,
    CaseStatus,
    CasePriority,
    KnowledgeState,
    ProblemStatus,
    ChangeType,
    ChangeStatus,
    RiskLevel,
    MajorIncidentStatus,
    MessageVisibility,
)

PASSWORD = "SecurePassword123!"

async def seed_demo():
    print("🌱 Starting Finora IT Helpdesk Demo Data Seeder...")
    async with AsyncSessionLocal() as session:
        # 1. Organization & Tenant Policy
        res_org = await session.execute(select(Organization).where(Organization.slug == "finora-technologies"))
        org = res_org.scalar_one_or_none()
        if not org:
            org = Organization(
                name="Finora Technologies Corp",
                slug="finora-technologies",
                domain_whitelist=["finora.local", "enterprise.com"],
                sla_tier="enterprise",
                max_users=500,
                is_active=True,
            )
            session.add(org)
            await session.flush()
            
            policy = TenantPolicy(
                organization_id=org.id,
                data_retention_days=365,
                require_mfa=False,
                allow_password_auth=True,
                allow_google_oauth=True,
                ai_auto_triage_enabled=True,
                ai_autofix_enabled=True,
            )
            session.add(policy)
            print(f"  ✓ Created Organization: {org.name}")

        # 2. Teams
        res_team = await session.execute(select(Team).where(Team.name == "Global IT & Cloud Infrastructure"))
        team = res_team.scalar_one_or_none()
        if not team:
            team = Team(
                name="Global IT & Cloud Infrastructure",
                description="L1/L2 Technical Support, Endpoints, Network & Cloud Services",
                organization_id=org.id,
            )
            session.add(team)
            await session.flush()
            print(f"  ✓ Created Team: {team.name}")

        # 3. Users for all 5 Roles
        roles_config = [
            ("requester@enterprise.com", UserRole.REQUESTER, "Austin Campus", None),
            ("operator@enterprise.com", UserRole.OPERATOR, "Austin HQ", team.id),
            ("teamlead@enterprise.com", UserRole.TEAM_LEAD, "Austin HQ", team.id),
            ("manager@enterprise.com", UserRole.MANAGER, "Executive Center", team.id),
            ("admin@enterprise.com", UserRole.ADMINISTRATOR, "Global HQ", None),
        ]

        users = {}
        for email, role, site, t_id in roles_config:
            res_user = await session.execute(select(User).where(User.email == email))
            u = res_user.scalar_one_or_none()
            if not u:
                u = User(
                    email=email,
                    password_hash=hash_password(PASSWORD),
                    role=role,
                    site=site,
                    team_id=t_id,
                    organization_id=org.id,
                    email_verified=True,
                    auth_provider=AuthProvider.PASSWORD,
                    availability_status=AvailabilityStatus.AVAILABLE,
                )
                session.add(u)
                await session.flush()
                print(f"  ✓ Created User [{role.value.upper()}]: {email} (Password: {PASSWORD})")
            else:
                # Ensure password and verification are set
                u.password_hash = hash_password(PASSWORD)
                u.email_verified = True
                u.organization_id = org.id
                u.team_id = t_id
                print(f"  ✓ Updated User [{role.value.upper()}]: {email} (Password: {PASSWORD})")
            users[role] = u

        # Set Lead for team
        if not team.lead_id and UserRole.TEAM_LEAD in users:
            team.lead_id = users[UserRole.TEAM_LEAD].id

        # 4. Sample Cases (Tickets)
        now = datetime.now(timezone.utc)
        sample_cases = [
            {
                "ref": "INC-2026-00001",
                "title": "Thunderbolt Dock Dual Display Flickering",
                "description": "External monitors flicker and disconnect intermittently when connected via USB-C dock under high charging wattage.",
                "type": CaseType.INCIDENT,
                "status": CaseStatus.IN_ASSESSMENT,
                "priority": CasePriority.P2,
                "requester": users[UserRole.REQUESTER],
                "owner": users[UserRole.OPERATOR],
            },
            {
                "ref": "REQ-2026-00002",
                "title": "AWS Production Read-Only Access Provisioning",
                "description": "Requesting AWS IAM role access to staging and production CloudWatch logs for incident analysis.",
                "type": CaseType.SERVICE_REQUEST,
                "status": CaseStatus.NEW,
                "priority": CasePriority.P3,
                "requester": users[UserRole.REQUESTER],
                "owner": None,
            },
            {
                "ref": "INC-2026-00003",
                "title": "VPN AnyConnect Authentication Timeout",
                "description": "Connecting to US-East VPN gateway hangs on SAML challenge and times out after 60 seconds.",
                "type": CaseType.INCIDENT,
                "status": CaseStatus.ASSIGNED,
                "priority": CasePriority.P1,
                "requester": users[UserRole.REQUESTER],
                "owner": users[UserRole.OPERATOR],
            },
            {
                "ref": "INC-2026-00004",
                "title": "Password Reset Assistance for SSO Portal",
                "description": "Locked out of Workday and corporate Jira portal after entering wrong PIN three times.",
                "type": CaseType.INCIDENT,
                "status": CaseStatus.RESOLVED,
                "priority": CasePriority.P4,
                "requester": users[UserRole.REQUESTER],
                "owner": users[UserRole.OPERATOR],
            },
        ]

        for c_data in sample_cases:
            res_c = await session.execute(select(Case).where(Case.reference_number == c_data["ref"]))
            c = res_c.scalar_one_or_none()
            if not c:
                c = Case(
                    reference_number=c_data["ref"],
                    title=c_data["title"],
                    description=c_data["description"],
                    type=c_data["type"],
                    status=c_data["status"],
                    priority=c_data["priority"],
                    requester_id=c_data["requester"].id,
                    owner_id=c_data["owner"].id if c_data["owner"] else None,
                    team_id=team.id,
                    organization_id=org.id,
                    site="Austin HQ",
                    resolved_at=now if c_data["status"] == CaseStatus.RESOLVED else None,
                )
                session.add(c)
                await session.flush()

                # SLA record
                sla = SLA(
                    case_id=c.id,
                    target_response_at=now + timedelta(hours=1),
                    target_resolve_at=now + timedelta(hours=8),
                    responded_at=now if c_data["owner"] else None,
                    resolved_at=now if c_data["status"] == CaseStatus.RESOLVED else None,
                )
                session.add(sla)

                # Sample message
                msg = Message(
                    case_id=c.id,
                    author_id=c_data["requester"].id,
                    visibility=MessageVisibility.REQUESTER_VISIBLE,
                    body=c_data["description"],
                )
                session.add(msg)
                print(f"  ✓ Created Case [{c.reference_number}]: {c.title}")

        # 5. Sample Knowledge Articles
        res_ka = await session.execute(select(KnowledgeArticle).where(KnowledgeArticle.title.like("%Thunderbolt%")))
        ka = res_ka.scalar_one_or_none()
        if not ka:
            ka = KnowledgeArticle(
                title="SOP: Resolving Thunderbolt Dock Dual Display Flickering",
                body="## Overview\nThis SOP resolves monitor flickering when laptops are connected to 85W+ docks.\n\n## Symptoms\nMonitors black out every 30-60 seconds under load.\n\n## Root Cause\nOutdated Intel Thunderbolt 4 firmware and display link power throttling.\n\n## Step-by-Step Resolution\n1. Disconnect dock power cable for 10 seconds.\n2. Update dock firmware via Dell/Lenovo firmware utility.\n3. In BIOS, disable PCIe aggressive power saving for Thunderbolt controllers.\n4. Reconnect display cables.",
                owner_id=users[UserRole.OPERATOR].id,
                organization_id=org.id,
                state=KnowledgeState.PUBLISHED,
            )
            session.add(ka)
            print(f"  ✓ Created Knowledge Article: {ka.title}")

        # 6. Sample Problem Management Record
        res_prob = await session.execute(select(Problem).where(Problem.problem_number == "PRB-2026-00001"))
        prob = res_prob.scalar_one_or_none()
        if not prob:
            prob = Problem(
                problem_number="PRB-2026-00001",
                title="Intermittent Corporate VPN Gateway Packet Loss",
                description="Packet drops observed on AnyConnect IPsec tunnel during 9 AM peak login hours.",
                root_cause="NAT connection pool exhaustion on primary firewall pair.",
                workaround="Reroute traffic through secondary gateway node vpn-backup.corp.",
                status=ProblemStatus.INVESTIGATING,
                priority=CasePriority.P2,
                owner_id=users[UserRole.TEAM_LEAD].id,
                organization_id=org.id,
            )
            session.add(prob)
            print(f"  ✓ Created Problem: {prob.problem_number}")

        # 7. Sample Change Request (Awaiting CAB Approval)
        res_chg = await session.execute(select(ChangeRequest).where(ChangeRequest.change_number == "CHG-2026-00001"))
        chg = res_chg.scalar_one_or_none()
        if not chg:
            chg = ChangeRequest(
                change_number="CHG-2026-00001",
                title="Upgrade Core Firewall Firmware to v12.4.1",
                description="Apply security patch and memory leak fix to primary core firewall cluster.",
                reason="CVE-2026-8911 vulnerability mitigation and connection table stability.",
                change_type=ChangeType.NORMAL,
                status=ChangeStatus.PENDING_CAB,
                risk_level=RiskLevel.MODERATE,
                requester_id=users[UserRole.TEAM_LEAD].id,
                organization_id=org.id,
                scheduled_start=now + timedelta(days=2),
                scheduled_end=now + timedelta(days=2, hours=3),
                implementation_plan="1. Failover to secondary node.\n2. Apply patch to primary.\n3. Verify routes.\n4. Failback.",
                rollback_plan="Revert to previous firmware boot partition.",
                test_plan="Execute automated ping sweeps and state table checks.",
            )
            session.add(chg)
            print(f"  ✓ Created Change Request: {chg.change_number}")

        # 8. Sample Major Incident
        res_mi = await session.execute(select(MajorIncident).where(MajorIncident.incident_number == "MI-2026-00001"))
        mi = res_mi.scalar_one_or_none()
        if not mi:
            # Link to P1 Case (INC-2026-00003)
            res_p1 = await session.execute(select(Case).where(Case.reference_number == "INC-2026-00003"))
            p1_case = res_p1.scalar_one()
            mi = MajorIncident(
                incident_number="MI-2026-00001",
                case_id=p1_case.id,
                title="Production ERP Cluster Latency Spike",
                executive_summary="ERP database queries experiencing 4x response degradation impacting order processing.",
                status=MajorIncidentStatus.ACTIVE,
                commander_id=users[UserRole.MANAGER].id,
                communications_lead_id=users[UserRole.TEAM_LEAD].id,
                impact_summary="Checkout and Inventory Sync services running at degraded throughput.",
                bridge_url="https://meet.corp.finora/war-room-erp",
            )
            session.add(mi)
            print(f"  ✓ Created Major Incident: {mi.incident_number}")

        await session.commit()
    print("✅ Finora IT Helpdesk Demo Seeding Complete!")

if __name__ == "__main__":
    asyncio.run(seed_demo())
