import asyncio
import logging

import asyncpg
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from .auth import routes as auth_routes
from .routes import health
from .routers import ws as ws_routes
from .spendsense import routes as spendsense_routes
from .spendsense.training import routes as training_routes
from .spendsense.ml import routes as ml_routes
from .spendsense.merchants import router as merchants_router
from .gmail import routes as gmail_routes
from .gmail import test_routes as gmail_test_routes
from .goals import routes as goals_routes
from .budgetpilot import routes as budgetpilot_routes
from .moneymoments import routes as moneymoments_routes
from .realtime_subscriber import redis_events_listener

# Import rules to trigger auto-registration
import app.goals.rules  # noqa: F401

logger = logging.getLogger(__name__)


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
    # Also allow Flutter app connections (mobile apps don't have origins, but we allow all for dev)
    allowed_origins = [
        frontend_origin,
        f"{frontend_origin}/",
        "http://localhost:3000",
        "http://localhost:3000/",
        "http://127.0.0.1:8000",
        "http://10.0.2.2:8000",  # Android emulator
        "*",  # Allow all origins for development (Flutter apps)
    ]
    # In production, restrict CORS to frontend origin only
    cors_origins = [str(settings.frontend_origin)] if settings.environment == "production" else allowed_origins
    application.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Configure logging level
    log_level_str = getattr(settings, 'log_level', 'INFO')
    log_level = getattr(logging, log_level_str.upper(), logging.INFO)
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    @application.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        """Global exception handler to log errors and return proper responses."""
        logger.error(
            f"Unhandled exception: {exc}",
            exc_info=True,
            extra={"path": request.url.path, "method": request.method},
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "detail": "Internal server error",
                "error": str(exc) if logger.level <= logging.DEBUG else None,
            },
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

    # Include health router at root and /health
    application.include_router(health.router, tags=["health"])
    application.include_router(health.router, prefix="/health", tags=["health"])
    application.include_router(auth_routes.router)
    application.include_router(spendsense_routes.router)
    application.include_router(training_routes.router)
    application.include_router(ml_routes.router)
    application.include_router(merchants_router, prefix="/api")
    application.include_router(gmail_routes.router)
    application.include_router(gmail_test_routes.router)
    application.include_router(goals_routes.router)
    application.include_router(budgetpilot_routes.router)
    application.include_router(moneymoments_routes.router)
    application.include_router(ws_routes.router)
    return application


app = create_app()

