from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_DIR.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(PROJECT_ROOT / ".env", BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "qr_pamyat"
    postgres_user: str = "qr_app"
    postgres_password: str = "qr_app"
    database_url: str = "postgresql+asyncpg://qr_app:qr_app@localhost:5432/qr_pamyat"

    api_host: str = "0.0.0.0"
    api_port: int = 8000
    jwt_secret: str = "dev_local_jwt_secret_change_in_production_32chars"
    jwt_access_expire_minutes: int = 30
    jwt_refresh_expire_days: int = 7
    cors_origins: str = "http://localhost:5173"

    yookassa_shop_id: str = ""
    yookassa_secret_key: str = ""
    yookassa_return_url: str = "http://127.0.0.1:5173/order/success"
    yookassa_webhook_secret: str = ""

    # Корень файлов на диске (абсолютный или относительный к корню проекта).
    # В БД хранятся только относительные ключи: memorials/{uuid}/photos/...
    media_storage_root: str = "uploads"
    media_storage_bucket: str = "local"

    @property
    def media_root_path(self) -> Path:
        root = Path(self.media_storage_root)
        if not root.is_absolute():
            root = PROJECT_ROOT / root
        return root.resolve()

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def yookassa_configured(self) -> bool:
        return bool(self.yookassa_shop_id and self.yookassa_secret_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
