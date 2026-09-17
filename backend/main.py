from contextlib import asynccontextmanager
from typing import AsyncGenerator
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from api.health import router as health_router
from api.auth.routes import router as auth_router
from api.cases.routes import router as cases_router
from api.attachments.routes import router as attachments_router
from api.notifications.routes import router as notifications_router
from api.ai.routes import router as ai_router
from api.escalations.routes import router as escalations_router
from api.knowledge.routes import router as knowledge_router
from api.approvals.routes import router as approvals_router
from api.problems.routes import router as problems_router
from api.changes.routes import router as changes_router
from api.major_incidents.routes import router as major_incidents_router
from api.autofix.routes import router as autofix_router
from api.reports.routes import router as reports_router
from scheduler import scheduler_manager


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Validate startup configuration per SRS §3.3
    settings.validate_startup()
    # Start background Sweep scheduler per SRS §3.5
    scheduler_manager.start()
    try:
        yield
    finally:
        # Graceful scheduler shutdown
        scheduler_manager.shutdown()


app = FastAPI(
    title="AI IT Helpdesk API",
    description="Backend API service for AI IT Helpdesk with human control and AI assistance",
    version="1.0.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)

# CORS configuration per SRS §3.7 (Explicit allowed origins, never '*')
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Standard Error Envelope per SRS §3.6:
# { "error": { "code": "STRING_CODE", "message": "...", "details": { ... } } }
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "The submitted data failed validation.",
                "details": exc.errors(),
            }
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    if isinstance(exc.detail, dict) and "error" in exc.detail:
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": "HTTP_ERROR",
                "message": str(exc.detail),
                "details": {},
            }
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected error occurred. Please try again later.",
                "details": str(exc) if settings.DEBUG else {},
            }
        },
    )


# API v1 Router Registration
app.include_router(health_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(cases_router, prefix="/api/v1")
app.include_router(attachments_router, prefix="/api/v1")
app.include_router(notifications_router, prefix="/api/v1")
app.include_router(ai_router, prefix="/api/v1")
app.include_router(escalations_router, prefix="/api/v1")
app.include_router(knowledge_router, prefix="/api/v1")
app.include_router(approvals_router, prefix="/api/v1")
app.include_router(problems_router, prefix="/api/v1")
app.include_router(changes_router, prefix="/api/v1")
app.include_router(major_incidents_router, prefix="/api/v1")
app.include_router(autofix_router, prefix="/api/v1")
app.include_router(reports_router, prefix="/api/v1")


@app.get("/")
async def root_redirect():
    return {
        "name": "AI IT Helpdesk API",
        "version": "1.0.0",
        "health": "/api/v1/health",
        "docs": "/docs" if settings.DEBUG else "disabled",
    }
