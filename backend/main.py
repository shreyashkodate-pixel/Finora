from contextlib import asynccontextmanager
from typing import AsyncGenerator
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from api.health import router as health_router


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Validate startup configuration per SRS §3.3
    settings.validate_startup()
    yield


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


@app.get("/")
async def root_redirect():
    return {
        "name": "AI IT Helpdesk API",
        "version": "1.0.0",
        "health": "/api/v1/health",
        "docs": "/docs" if settings.DEBUG else "disabled",
    }
