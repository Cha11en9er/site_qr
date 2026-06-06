from fastapi import APIRouter, Depends
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.lookups import PackageType
from app.schemas.health import DbHealthOut, HealthOut

router = APIRouter()


@router.get("/health", response_model=HealthOut)
async def health() -> HealthOut:
    return HealthOut(status="ok", service="qr-pamyat-api")


@router.get("/health/db", response_model=DbHealthOut)
async def health_db(db: AsyncSession = Depends(get_db)) -> DbHealthOut:
    try:
        await db.execute(text("SELECT 1"))
        count = await db.scalar(select(func.count()).select_from(PackageType))
        return DbHealthOut(
            status="ok",
            database="connected",
            package_types_count=count,
        )
    except Exception as exc:
        return DbHealthOut(
            status="error",
            database="disconnected",
            detail=str(exc),
        )
