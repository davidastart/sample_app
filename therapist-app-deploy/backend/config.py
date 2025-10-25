from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Database
    DATABASE_HOST: str = "oracle-db"
    DATABASE_PORT: int = 1521
    DATABASE_SERVICE: str = "FREEPDB1"
    DATABASE_USER: str = "therapist_app"
    DATABASE_PASSWORD: str
    
    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # OCI Generative AI
    OCI_COMPARTMENT_ID: str
    OCI_REGION: str = "us-ashburn-1"
    OCI_CONFIG_FILE: Optional[str] = "/app/.oci/config"
    
    # Application
    APP_NAME: str = "Therapist Office App"
    DEBUG: bool = False
    CORS_ORIGINS: str = "http://localhost:3000"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
