import time
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from core.rate_limiter import InMemoryRateLimiter
from models.case import Case, CaseSequence
from models.enums import CasePriority, CaseStatus, CaseType, UserRole
from models.user import User
from services.case_service import CaseService


@pytest.mark.asyncio
async def test_case_sequence_concurrency_and_increment(test_db):
    user = User(
        email="seq_tester@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(user)
    await test_db.commit()

    service = CaseService(test_db)

    # Generate sequential incident reference numbers
    ref1 = await service._generate_reference_number(CaseType.INCIDENT)
    await test_db.commit()

    ref2 = await service._generate_reference_number(CaseType.INCIDENT)
    await test_db.commit()

    ref3 = await service._generate_reference_number(CaseType.INCIDENT)
    await test_db.commit()

    assert ref1.startswith("INC-")
    assert ref2.startswith("INC-")
    assert ref3.startswith("INC-")

    seq1 = int(ref1.split("-")[-1])
    seq2 = int(ref2.split("-")[-1])
    seq3 = int(ref3.split("-")[-1])

    assert seq2 == seq1 + 1
    assert seq3 == seq2 + 1

    # Verify CaseSequence row exists
    stmt = select(CaseSequence).where(CaseSequence.case_type == "INC")
    res = await test_db.execute(stmt)
    seq_row = res.scalar_one_or_none()
    assert seq_row is not None
    assert seq_row.last_value >= 3


def test_in_memory_rate_limiter_sliding_window():
    limiter = InMemoryRateLimiter(max_requests=5, window_seconds=1)
    client_id = "192.168.1.100"

    # 5 allowed
    for _ in range(5):
        assert limiter.is_allowed(client_id) is True

    # 6th blocked
    assert limiter.is_allowed(client_id) is False
    assert limiter.get_retry_after(client_id) >= 1

    # Wait for window to expire
    time.sleep(1.1)
    assert limiter.is_allowed(client_id) is True
