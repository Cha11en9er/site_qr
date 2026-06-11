from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_optional_user
from app.core.config import get_settings
from app.core.database import get_db
from app.models.user import User
from app.schemas.memorials import MemorialCreate, MemorialOut, MemorialUpdate
from app.services import memorials as memorial_service

router = APIRouter()


@router.get("/me", response_model=list[MemorialOut])
async def list_my_memorials(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[MemorialOut]:
    settings = get_settings()
    return await memorial_service.list_user_memorials(db, settings, user)


@router.post("", response_model=MemorialOut)
async def create_memorial(
    payload: MemorialCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> MemorialOut:
    settings = get_settings()
    return await memorial_service.create_memorial(db, settings, user, payload)


@router.get("/{memorial_id}", response_model=MemorialOut)
async def get_memorial(
    memorial_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User | None, Depends(get_optional_user)] = None,
) -> MemorialOut:
    settings = get_settings()
    return await memorial_service.get_memorial(db, settings, memorial_id, user)


@router.get("/{memorial_id}/public", response_model=MemorialOut)
async def get_public_memorial(
    memorial_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> MemorialOut:
    settings = get_settings()
    return await memorial_service.get_memorial(
        db, settings, memorial_id, None, public_only=True
    )


@router.patch("/{memorial_id}", response_model=MemorialOut)
async def update_memorial(
    memorial_id: UUID,
    payload: MemorialUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> MemorialOut:
    settings = get_settings()
    return await memorial_service.update_memorial(db, settings, memorial_id, user, payload)
