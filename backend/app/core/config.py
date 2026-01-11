from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from pydantic import AnyHttpUrl, Field, PostgresDsn, RedisDsn, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict

APP_DIR = Path(__file__).resolve().parents[1]
BACKEND_DIR = APP_DIR.parent
ROOT_DIR = BACKEND_DIR.parent

for env_path in (BACKEND_DIR / ".env", ROOT_DIR / ".env"):
    if env_path.exists():
        load_dotenv(env_path, override=False)


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    environment: str = Field(default="development", alias="ENVIRONMENT")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    workers: int = Field(default=2, alias="WORKERS")
    supabase_url: AnyHttpUrl = Field(alias="SUPABASE_URL")
    supabase_anon_key: str = Field(alias="SUPABASE_ANON_KEY")
    supabase_service_role_key: str = Field(alias="SUPABASE_SERVICE_ROLE_KEY")
    supabase_jwt_secret: str = Field(alias="SUPABASE_JWT_SECRET")
    frontend_origin: AnyHttpUrl = Field(default="http://localhost:5173", alias="FRONTEND_ORIGIN")
    postgres_dsn: PostgresDsn = Field(alias="POSTGRES_URL")
    redis_url: RedisDsn = Field(default="redis://localhost:6379/0", alias="REDIS_URL")
    gmail_client_id: str = Field(alias="GMAIL_CLIENT_ID")
    gmail_client_secret: str = Field(alias="GMAIL_CLIENT_SECRET")
    gmail_redirect_uri: AnyHttpUrl = Field(alias="GMAIL_REDIRECT_URI")
    gmail_token_uri: AnyHttpUrl = Field(
        default="https://oauth2.googleapis.com/token", alias="GMAIL_TOKEN_URI"
    )
    # Pub/Sub for Gmail real-time notifications
    gcp_project_id: str | None = Field(default=None, alias="GCP_PROJECT_ID")
    gmail_pubsub_topic: str = Field(default="gmail-events", alias="GMAIL_PUBSUB_TOPIC")
    google_application_credentials: str | None = Field(
        default=None, alias="GOOGLE_APPLICATION_CREDENTIALS"
    )
    
    # Base directory for models and data
    base_dir: Path = Field(default=BACKEND_DIR, alias="BASE_DIR")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Return cached settings instance."""
    try:
        return Settings()
    except ValidationError as exc:  # pragma: no cover - startup validation helper
        missing = ", ".join(err["loc"][0] for err in exc.errors())
        raise RuntimeError(
            "Missing required environment variables. "
            f"Please set: {missing}. Check backend/.env."
        ) from exc

