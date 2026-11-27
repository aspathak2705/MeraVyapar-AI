from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.db.session import get_db
from app.schemas.common import APIResponse

router = APIRouter()


@router.get("/health", response_model=APIResponse)
def health_check(db: Session = Depends(get_db)):
    db_status = "healthy"
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    return APIResponse(
        success=True,
        message="MeraVyapar AI Service Operational",
        data={
            "service": "meravyapar-api",
            "status": "healthy" if db_status == "healthy" else "degraded",
            "database": db_status,
            "version": "0.1.0"
        }
    )
