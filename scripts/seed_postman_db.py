import asyncio
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent / "backend"))

from core.security import hash_password
from db.session import Base
import models
from models.user import User
from models.enums import UserRole, AuthProvider
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select

DB_URL = "sqlite+aiosqlite:///backend/postman_test.db"

async def seed():
    engine = create_async_engine(DB_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    
    async with session_factory() as session:
        # Check and seed Operator
        res = await session.execute(select(User).where(User.email == "operator_pm@enterprise.com"))
        if not res.scalar_one_or_none():
            op = User(
                email="operator_pm@enterprise.com",
                password_hash=hash_password("SecurePassword123!"),
                role=UserRole.OPERATOR,
                site="Campus North",
                email_verified=True,
                auth_provider=AuthProvider.PASSWORD,
            )
            session.add(op)

        # Check and seed Lead
        res = await session.execute(select(User).where(User.email == "lead_pm@enterprise.com"))
        if not res.scalar_one_or_none():
            lead = User(
                email="lead_pm@enterprise.com",
                password_hash=hash_password("SecurePassword123!"),
                role=UserRole.TEAM_LEAD,
                site="Campus North",
                email_verified=True,
                auth_provider=AuthProvider.PASSWORD,
            )
            session.add(lead)

        await session.commit()
    
    await engine.dispose()
    print("Database seeded with Operator and Lead successfully.")

if __name__ == "__main__":
    asyncio.run(seed())
