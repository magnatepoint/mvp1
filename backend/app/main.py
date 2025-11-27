import asyncio

import asyncpg
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from .auth import routes as auth_routes
from .routes import health
from .routers import ws as ws_routes
from .spendsense import routes as spendsense_routes
from .spendsense.training import routes as training_routes
from .spendsense.ml import routes as ml_routes
from .gmail import routes as gmail_routes
from .gmail import test_routes as gmail_test_routes
from .realtime_subscriber import redis_events_listener


def create_app() -> FastAPI:
    """Create a configured FastAPI application instance."""
    settings = get_settings()
    application = FastAPI(
        title="MVP Backend",
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    frontend_origin = str(settings.frontend_origin).rstrip("/")
    # Allow both Vite (5173) and Next.js (3000) dev servers
    allowed_origins = [
        frontend_origin,
        f"{frontend_origin}/",
        "http://localhost:3000",
        "http://localhost:3000/",
    ]
    application.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @application.on_event("startup")
    async def startup() -> None:
        application.state.db_pool = await asyncpg.create_pool(
            str(settings.postgres_dsn),
            min_size=1,
            max_size=5,
            statement_cache_size=0,
        )
        application.state.redis_listener = asyncio.create_task(redis_events_listener())

    @application.on_event("shutdown")
    async def shutdown() -> None:
        pool = getattr(application.state, "db_pool", None)
        if pool is not None:
            try:
                # Close pool with timeout to prevent hanging
                await asyncio.wait_for(pool.close(), timeout=5.0)
            except (asyncio.TimeoutError, Exception):
                # Force terminate if close times out or fails (terminate is synchronous)
                pool.terminate()
        listener = getattr(application.state, "redis_listener", None)
        if listener is not None:
            listener.cancel()

    application.include_router(health.router, prefix="/health", tags=["health"])
    application.include_router(auth_routes.router)
    application.include_router(spendsense_routes.router)
    application.include_router(training_routes.router)
    application.include_router(ml_routes.router)
    application.include_router(gmail_routes.router)
    application.include_router(gmail_test_routes.router)
    application.include_router(ws_routes.router)
    return application


app = create_app()

