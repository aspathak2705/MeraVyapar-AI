from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    LOG_LEVEL: str = "INFO"
    PROJECT_NAME: str = "MeraVyapar AI API"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgrespassword@localhost:5432/meravyapar_db"

    # Supabase Auth
    SUPABASE_URL: Optional[str] = None
    SUPABASE_PUBLISHABLE_KEY: Optional[str] = None
    SUPABASE_JWT_SECRET: str = "dev-secret-change-in-production-min-32-chars!!"

    # Redis
    REDIS_URL: Optional[str] = "redis://localhost:6379/0"

    # Supabase Storage & Service Key (Backend Only)
    SUPABASE_STORAGE_BUCKET: str = "financial-evidence"
    SUPABASE_SERVICE_ROLE_KEY: Optional[str] = None

    # Cloudflare R2
    CLOUDFLARE_R2_ENDPOINT: Optional[str] = None
    CLOUDFLARE_R2_ACCESS_KEY_ID: Optional[str] = None
    CLOUDFLARE_R2_SECRET_ACCESS_KEY: Optional[str] = None
    # OpenRouter & Nemotron Intelligence Configuration
    OPENROUTER_API_KEY: Optional[str] = None
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"
    FINANCIAL_INTELLIGENCE_MODEL: str = "nvidia/nemotron-3-super-120b-a12b:free"
    NEMOTRON_REASONING_ENABLED: bool = True

    model_config = SettingsConfigDict(
        env_file=[".env", "../.env"],
        env_file_encoding="utf-8",
        extra="ignore"
    )



settings = Settings()
