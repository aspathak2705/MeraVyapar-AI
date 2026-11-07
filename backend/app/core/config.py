from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    LOG_LEVEL: str = "INFO"
    PROJECT_NAME: str = "MeraVyapar AI API"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: Optional[str] = None

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

    # SerpApi Intelligence Configuration (Backend Only)
    SERPAPI_API_KEY: Optional[str] = None
    SERPAPI_BASE_URL: str = "https://serpapi.com/search"
    SERPAPI_CACHE_TTL_SECONDS: int = 86400  # 24-hour deterministic cache
    SERPAPI_TIMEOUT_SECONDS: float = 10.0

    # Gnani AI Speech Stack Configuration (Backend Only)
    GNANI_API_KEY: Optional[str] = None
    GNANI_API_BASE_URL: str = "https://api.vachana.ai"
    GNANI_STT_MODEL: str = "prisma-v2.5"
    GNANI_TTS_MODEL: str = "timbre-v2.5"
    GNANI_DEFAULT_VOICE: str = "Nalini"
    GNANI_DEFAULT_LANGUAGE: str = "hi-IN"
    GNANI_TIMEOUT_SECONDS: float = 10.0

    # OpenRouter & Nemotron Intelligence Configuration
    OPENROUTER_API_KEY: Optional[str] = None
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"
    FINANCIAL_INTELLIGENCE_MODEL: str = "nvidia/nemotron-3-super-120b-a12b:free"
    NEMOTRON_REASONING_ENABLED: bool = True

    # External Provider Configuration & Modes
    EXTERNAL_PROVIDER_MODE: str = "simulation"  # Options: simulation, production, disabled
    ENABLE_DEMO_ENDPOINTS: bool = True
    WHATSAPP_PROVIDER: str = "simulation"
    WHATSAPP_PROVIDER_KEY: Optional[str] = None
    SMS_PROVIDER: str = "simulation"
    SMS_PROVIDER_KEY: Optional[str] = None
    PAYMENT_PROVIDER: str = "simulation"
    RAZORPAY_KEY_ID: Optional[str] = None
    RAZORPAY_KEY_SECRET: Optional[str] = None
    RAZORPAY_WEBHOOK_SECRET: Optional[str] = None

    model_config = SettingsConfigDict(
        env_file=[".env", "../.env"],
        env_file_encoding="utf-8",
        extra="ignore"
    )



settings = Settings()
