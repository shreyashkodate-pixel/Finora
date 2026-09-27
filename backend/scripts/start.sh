#!/bin/sh
set -e

echo "==> AI IT Helpdesk Backend Container Starting..."

# 1. Run database migrations to current head per Phase 4F specification
echo "==> Executing database migrations (alembic upgrade head)..."
alembic upgrade head

# 2. Start Uvicorn API server with exec for correct signal handling
echo "==> Starting Uvicorn server on ${HOST:-0.0.0.0}:${PORT:-8000}..."
exec uvicorn main:app --host "${HOST:-0.0.0.0}" --port "${PORT:-8000}"
