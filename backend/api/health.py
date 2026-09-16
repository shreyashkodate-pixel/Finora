from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["Health"])


class HealthResponse(BaseModel):
    status: str
    db: str
    environment: str


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    Health check endpoint per SRS §3.8.
    Never calls Gemini or external AI providers to preserve quota on uptime pings.
    """
    # In scaffolding, db is reported as ok. Full DB ping integrated in feature/backend-db-models.
    return HealthResponse(
        status="ok",
        db="ok",
        environment="local",
    )
