import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check_returns_ok(async_client: AsyncClient):
    """Verify GET /api/v1/health returns 200 OK with expected envelope per SRS §3.8."""
    response = await async_client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["db"] == "ok"
    assert "environment" in data


@pytest.mark.asyncio
async def test_root_endpoint(async_client: AsyncClient):
    """Verify GET / returns API metadata and health link."""
    response = await async_client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "AI IT Helpdesk API"
    assert data["health"] == "/api/v1/health"
