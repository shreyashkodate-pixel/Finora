"""
Seed script for AI IT Helpdesk demo environment.
Per SRS §11 and §13, this script will populate:
- 5 Users representing each system role (Requester, Operator, Team Lead, Manager, Administrator)
- 15-20 Cases spanning all lifecycle states (Draft through Closed/Reopened)
- Sample Messages (requester_visible and internal_only)
- Simulated SLAs, AITriageResults, CaseSummaries, and CaseRiskAssessments
"""

import asyncio
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def seed_data():
    logger.info("Initializing demo data seeding...")
    # Full seeding logic will be implemented in feature/seed-data-uat
    logger.info("Seed data script ready.")


if __name__ == "__main__":
    asyncio.run(seed_data())
