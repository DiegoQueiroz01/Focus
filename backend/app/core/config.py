from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    jwt_secret_key: str = Field(min_length=32)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24

    cors_origins: list[str] = []
    cors_origin_regex: str | None = None
    workouts_page_max: int = 50

    # Consulta o DNS para confirmar que o domínio do e-mail existe e recebe mensagens.
    email_check_deliverability: bool = True

    # Usa a foto do Gravatar (https://gravatar.com) ligada ao e-mail como foto de perfil.
    gravatar_enabled: bool = True

    # Onde ficam as fotos do catálogo de exercícios (free-exercise-db, versão fixada).
    catalog_image_base_url: str = (
        "https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db"
        "@f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/exercises"
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
