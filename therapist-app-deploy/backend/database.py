from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import settings
import logging

logger = logging.getLogger(__name__)

# Oracle connection string
DATABASE_URL = (
    f"oracle+oracledb://{settings.DATABASE_USER}:"
    f"{settings.DATABASE_PASSWORD}@"
    f"{settings.DATABASE_HOST}:{settings.DATABASE_PORT}/"
    f"{settings.DATABASE_SERVICE}"
)

engine = create_engine(
    DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Dependency for FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Test connection
def test_connection():
    try:
        with engine.connect() as conn:
            result = conn.execute("SELECT 1 FROM DUAL")
            logger.info("Database connection successful")
            return True
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        return False
