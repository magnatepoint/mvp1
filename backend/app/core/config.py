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
    google_credentials_json: str | None = Field(
        default=None, alias="GOOGLE_CREDENTIALS_JSON"
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
        settings = Settings()
        
        # Handle GOOGLE_CREDENTIALS_JSON -> GOOGLE_APPLICATION_CREDENTIALS file
        if settings.google_credentials_json:
            import json
            import tempfile
            import os
            
            try:
                # Validate JSON first
                creds_dict = json.loads(settings.google_credentials_json)
                
                # Write to specific temp file so it persists for this run
                # Using /tmp/gcp_creds.json or similar could be risky if concurrent runs,
                # but valid for container usage.
                # Safer: NamedTemporaryFile with delete=False
                with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp:
                    json.dump(creds_dict, tmp)
                    tmp_path = tmp.name
                
                settings.google_application_credentials = tmp_path
                # Set env var for Google client libraries that read os.environ directly
                os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = tmp_path
                
            except Exception as e:
                # Log invalid JSON but don't crash app startup immediately?
                # Or maybe we should crash. For now, print error.
                print(f"WARNING: Failed to process GOOGLE_CREDENTIALS_JSON: {e}")

        return settings
    except ValidationError as exc:  # pragma: no cover - startup validation helper
        missing = ", ".join(err["loc"][0] for err in exc.errors())
        raise RuntimeError(
            "Missing required environment variables. "
            f"Please set: {missing}. Check backend/.env."
        ) from exc

