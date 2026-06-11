from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.database import get_db
from app.models.user import User
from app.schemas.media import MediaUploadResponse
from app.services import memorials as memorial_service
from app.services.media_storage import (
    ALLOWED_IMAGE_TYPES,
    ALLOWED_VIDEO_TYPES,
    MAX_IMAGE_BYTES,
    MAX_VIDEO_BYTES,
    absolute_path,
    build_storage_key,
    normalize_storage_key,
    save_upload_file,
)

router = APIRouter()


@router.post("/upload", response_model=MediaUploadResponse)
async def upload_media(
    memorial_id: Annotated[UUID, Form()],
    media_type: Annotated[str, Form()],
    file: UploadFile = File(...),
    db: Annotated[AsyncSession, Depends(get_db)] = None,
    user: Annotated[User, Depends(get_current_user)] = None,
) -> MediaUploadResponse:
    settings = get_settings()

    if media_type not in {"portrait", "photo", "video"}:
        from fastapi import HTTPException

        raise HTTPException(status_code=400, detail="INVALID_MEDIA_TYPE")

    folder = {"portrait": "portrait", "photo": "photos", "video": "videos"}[media_type]
    if not file.content_type:
        from fastapi import HTTPException

        raise HTTPException(status_code=400, detail="UNSUPPORTED_FILE_TYPE")

    allowed = ALLOWED_IMAGE_TYPES if media_type != "video" else ALLOWED_VIDEO_TYPES
    max_bytes = MAX_IMAGE_BYTES if media_type != "video" else MAX_VIDEO_BYTES

    storage_key = build_storage_key(memorial_id, folder, file.content_type)
    size_bytes = await save_upload_file(
        settings,
        file,
        storage_key,
        max_bytes=max_bytes,
        allowed_types=allowed,
    )

    record = await memorial_service.save_media_record(
        db,
        settings,
        user,
        memorial_id,
        media_type,
        storage_key,
        file.content_type,
        size_bytes,
        file.filename or "upload",
    )

    return MediaUploadResponse(
        id=record.id,
        storage_key=record.storage_key,
        url=record.url,
        mime_type=record.mime_type,
        size_bytes=record.size_bytes,
        original_filename=record.original_filename,
        media_type=media_type,
    )


@router.get("/files/{storage_key:path}")
async def serve_media_file(storage_key: str) -> FileResponse:
    settings = get_settings()
    key = normalize_storage_key(storage_key)
    path = absolute_path(settings, key)
    if not path.exists():
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="FILE_NOT_FOUND")
    return FileResponse(path)


@router.delete("/{media_id}")
async def delete_media(
    media_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> dict[str, str]:
    settings = get_settings()
    await memorial_service.delete_media_file(db, settings, user, media_id)
    return {"status": "deleted"}
