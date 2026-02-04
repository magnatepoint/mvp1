"""FastAPI application package for the MVP backend."""

from .main import app

# Alias so "uvicorn app:main" works (correct form is "uvicorn app.main:app" or "uvicorn app:app")
main = app

__all__ = ["app", "main"]

