from pathlib import Path

 

from pydantic import model_validator

from pydantic_settings import BaseSettings, SettingsConfigDict

 

 

BACKEND_DIR = Path(__file__).resolve().parents[2]

 

 

class Settings(BaseSettings):

    SECRET_KEY: str = "change_me"

    ALGORITHM: str = "HS256"

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    DATABASE_URL: str = "sqlite:///./vocabgen.db"

    ENVIRONMENT: str = "development"

    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:5173,http://localhost:8080,http://localhost:5000"

    AI_PROVIDER: str = "groq"

    GROQ_API_KEY: str = ""

    GROQ_MODEL: str = "llama-3.1-8b-instant"

    SMTP_HOST: str = ""

    SMTP_PORT: int = 587

    SMTP_USERNAME: str = ""

    SMTP_PASSWORD: str = ""

    SMTP_FROM_EMAIL: str = ""

    SMTP_FROM_NAME: str = "AI VocabGen"

    SMTP_USE_TLS: bool = True

    SMTP_USE_SSL: bool = False

    APP_NAME: str = "AI VocabGen"

 

    model_config = SettingsConfigDict(

        env_file=BACKEND_DIR / ".env",

        env_file_encoding="utf-8",

    )

 

    @model_validator(mode="after")

    def check_production_secrets(self) -> "Settings":

        if self.ENVIRONMENT.lower() == "production":

            if self.SECRET_KEY == "change_me":

                raise ValueError(

                    "SECRET_KEY must be changed from the default value in production. "

                    "Set a strong random key in your .env file."

                )

            if not self.SECRET_KEY or len(self.SECRET_KEY) < 32:

                raise ValueError(

                    "SECRET_KEY must be at least 32 characters long in production."

                )

        return self

 

 

settings = Settings()
