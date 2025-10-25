from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from config import settings
from database import get_db, test_connection
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="HIPAA-compliant treatment planning application"
)

# CORS middleware
origins = settings.CORS_ORIGINS.split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    """Run on application startup"""
    logger.info("Starting Therapist Office API...")
    if test_connection():
        logger.info("Database connection verified")
    else:
        logger.error("Database connection failed!")

@app.get("/")
async def root():
    return {
        "message": "Therapist Office API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check(db: Session = Depends(get_db)):
    """Health check endpoint"""
    try:
        # Test database connection
        db.execute("SELECT 1 FROM DUAL")
        return {
            "status": "healthy",
            "database": "connected",
            "version": "1.0.0"
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service unavailable"
        )

@app.get("/api/info")
async def api_info():
    """API information endpoint"""
    return {
        "app_name": settings.APP_NAME,
        "version": "1.0.0",
        "database_host": settings.DATABASE_HOST,
        "oci_region": settings.OCI_REGION,
    }

# Future router imports will go here
# from routers import auth, patients, sessions, treatment_plans
# app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
# app.include_router(patients.router, prefix="/api/patients", tags=["Patients"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
