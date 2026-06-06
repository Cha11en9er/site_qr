from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.lookups import PackageType
from app.schemas.lookups import PackageTypePublic

router = APIRouter()


@router.get("", response_model=list[PackageTypePublic])
async def list_packages(db: AsyncSession = Depends(get_db)) -> list[PackageTypePublic]:
    result = await db.scalars(
        select(PackageType)
        .where(PackageType.is_active.is_(True))
        .order_by(PackageType.sort_order, PackageType.id)
    )
    packages = result.all()
    return [
        PackageTypePublic(
            id=item.id,
            code=item.code,
            name=item.name,
            price_rub=item.price_rub,
            max_photos=item.max_photos,
            max_video_seconds=item.max_video_seconds,
            max_video_minutes=item.max_video_seconds // 60,
        )
        for item in packages
    ]


@router.get("/{code}", response_model=PackageTypePublic)
async def get_package_by_code(
    code: str,
    db: AsyncSession = Depends(get_db),
) -> PackageTypePublic:
    item = await db.scalar(
        select(PackageType).where(PackageType.code == code, PackageType.is_active.is_(True))
    )
    if item is None:
        raise HTTPException(status_code=404, detail=f"Package '{code}' not found")
    return PackageTypePublic(
        id=item.id,
        code=item.code,
        name=item.name,
        price_rub=item.price_rub,
        max_photos=item.max_photos,
        max_video_seconds=item.max_video_seconds,
        max_video_minutes=item.max_video_seconds // 60,
    )
