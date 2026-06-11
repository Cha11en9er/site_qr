from __future__ import annotations

import re
import secrets
import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.db.procedures import call_sp, sp_all, sp_one, sp_scalar
from app.models.lookups import PackageType
from app.models.user import User
from app.schemas.memorials import MemorialCreate, MemorialMediaItem, MemorialOut, MemorialUpdate


PACKAGE_CODE_MAP = {
    "standard": "standard",
    "premium": "premium",
    "max": "maximum",
}


def _media_url(settings: Settings, storage_key: str) -> str:
    return f"/api/v1/media/files/{storage_key}"


def _slug_from_name(full_name: str) -> str:
    base = re.sub(r"[^a-z0-9]+", "-", full_name.lower()).strip("-")[:40] or "memorial"
    return f"{base}-{secrets.token_hex(3)}"


async def _get_package(db: AsyncSession, package_code: str) -> PackageType:
    db_code = PACKAGE_CODE_MAP[package_code]
    package = await db.scalar(
        select(PackageType).where(PackageType.code == db_code, PackageType.is_active.is_(True))
    )
    if package is None:
        raise HTTPException(status_code=404, detail="PACKAGE_NOT_FOUND")
    return package


async def _lookup_media_type_id(db: AsyncSession, code: str) -> int:
    type_id = await sp_scalar(
        db,
        "SELECT sp_lookup_media_type_id(:code)",
        {"code": code},
    )
    if type_id is None:
        raise HTTPException(status_code=500, detail=f"MEDIA_TYPE_{code}_NOT_FOUND")
    return int(type_id)


async def resolve_storage_shard(db: AsyncSession, memorial_id: uuid.UUID) -> uuid.UUID:
    """Папка на диске: order_id (если QR привязан), иначе memorial_id."""
    order_id = await sp_scalar(
        db,
        "SELECT order_id FROM qr_codes WHERE memorial_id = :memorial_id LIMIT 1",
        {"memorial_id": memorial_id},
    )
    return order_id if order_id else memorial_id


async def _lookup_processing_status_id(db: AsyncSession, code: str = "ready") -> int:
    status_id = await sp_scalar(
        db,
        "SELECT sp_lookup_processing_status_id(:code)",
        {"code": code},
    )
    if status_id is None:
        raise HTTPException(status_code=500, detail="MEDIA_STATUS_NOT_FOUND")
    return int(status_id)


async def create_memorial(
    db: AsyncSession,
    settings: Settings,
    user: User,
    payload: MemorialCreate,
) -> MemorialOut:
    package = await _get_package(db, payload.package_type)
    memorial_id = uuid.uuid4()
    slug = _slug_from_name(payload.full_name)

    await call_sp(
        db,
        """
        SELECT sp_create_memorial(
            :id, :owner_user_id, :public_slug, :deceased_full_name,
            :birth_date, :death_date, :father_full_name, :mother_full_name, :epitaph,
            :package_type_id, :max_photos, :max_video_seconds
        )
        """,
        {
            "id": memorial_id,
            "owner_user_id": user.id,
            "public_slug": slug,
            "deceased_full_name": payload.full_name,
            "birth_date": payload.birth_date,
            "death_date": payload.death_date,
            "father_full_name": payload.father_name,
            "mother_full_name": payload.mother_name,
            "epitaph": payload.epitaph,
            "package_type_id": package.id,
            "max_photos": package.max_photos,
            "max_video_seconds": package.max_video_seconds,
        },
    )
    await db.commit()
    return await get_memorial(db, settings, memorial_id, user)


async def _assert_owner(db: AsyncSession, memorial_id: uuid.UUID, user: User) -> None:
    owner_id = await sp_scalar(
        db,
        "SELECT sp_memorial_owner_id(:id)",
        {"id": memorial_id},
    )
    if owner_id is None:
        raise HTTPException(status_code=404, detail="MEMORIAL_NOT_FOUND")
    if owner_id != user.id and user.role.code != "admin":
        raise HTTPException(status_code=403, detail="FORBIDDEN")


async def update_memorial(
    db: AsyncSession,
    settings: Settings,
    memorial_id: uuid.UUID,
    user: User,
    payload: MemorialUpdate,
) -> MemorialOut:
    await _assert_owner(db, memorial_id, user)

    has_changes = any(
        value is not None
        for value in (
            payload.full_name,
            payload.birth_date,
            payload.death_date,
            payload.father_name,
            payload.mother_name,
            payload.epitaph,
            payload.grave_address,
            payload.grave_lat,
            payload.grave_lng,
            payload.is_published,
        )
    )

    if has_changes:
        try:
            await call_sp(
                db,
                """
                SELECT sp_update_memorial(
                    :id, :actor_user_id, :is_admin,
                    :set_full_name, :full_name,
                    :set_birth_date, :birth_date,
                    :set_death_date, :death_date,
                    :set_father_name, :father_name,
                    :set_mother_name, :mother_name,
                    :set_epitaph, :epitaph,
                    :set_grave_address, :grave_address,
                    :set_grave_lat, :grave_lat,
                    :set_grave_lng, :grave_lng,
                    :set_is_published, :is_published
                )
                """,
                {
                    "id": memorial_id,
                    "actor_user_id": user.id,
                    "is_admin": user.role.code == "admin",
                    "set_full_name": payload.full_name is not None,
                    "full_name": payload.full_name,
                    "set_birth_date": payload.birth_date is not None,
                    "birth_date": payload.birth_date,
                    "set_death_date": payload.death_date is not None,
                    "death_date": payload.death_date,
                    "set_father_name": payload.father_name is not None,
                    "father_name": payload.father_name,
                    "set_mother_name": payload.mother_name is not None,
                    "mother_name": payload.mother_name,
                    "set_epitaph": payload.epitaph is not None,
                    "epitaph": payload.epitaph,
                    "set_grave_address": payload.grave_address is not None,
                    "grave_address": payload.grave_address,
                    "set_grave_lat": payload.grave_lat is not None,
                    "grave_lat": payload.grave_lat,
                    "set_grave_lng": payload.grave_lng is not None,
                    "grave_lng": payload.grave_lng,
                    "set_is_published": payload.is_published is not None,
                    "is_published": payload.is_published,
                },
            )
        except Exception as exc:
            err = str(getattr(exc, "orig", exc))
            if "MEMORIAL_NOT_FOUND" in err:
                raise HTTPException(status_code=404, detail="MEMORIAL_NOT_FOUND") from exc
            if "FORBIDDEN" in err:
                raise HTTPException(status_code=403, detail="FORBIDDEN") from exc
            raise
        await db.commit()

    return await get_memorial(db, settings, memorial_id, user)


def _package_code_to_frontend(code: str) -> str:
    return "max" if code == "maximum" else code


def _build_memorial_out(settings: Settings, row: dict, media_rows: list[dict]) -> MemorialOut:
    portrait = None
    photos: list[MemorialMediaItem] = []
    videos: list[MemorialMediaItem] = []

    for item in media_rows:
        media_item = MemorialMediaItem(
            id=item["id"],
            storage_key=item["storage_key"],
            url=_media_url(settings, item["storage_key"]),
            mime_type=item["mime_type"],
            size_bytes=item["size_bytes"],
            original_filename=item["original_filename"],
            duration_seconds=item["duration_seconds"],
            sort_order=item["sort_order"],
        )
        if item["media_type"] == "portrait":
            portrait = media_item
        elif item["media_type"] == "video":
            videos.append(media_item)
        else:
            photos.append(media_item)

    return MemorialOut(
        id=row["id"],
        public_slug=row["public_slug"],
        full_name=row["full_name"],
        birth_date=row["birth_date"],
        death_date=row["death_date"],
        father_name=row["father_name"],
        mother_name=row["mother_name"],
        epitaph=row["epitaph"],
        grave_address=row["grave_address"],
        grave_lat=row["grave_lat"],
        grave_lng=row["grave_lng"],
        package_type=_package_code_to_frontend(row["package_code"]),
        max_photos=row["max_photos"],
        max_video_seconds=row["max_video_seconds"],
        is_published=row["is_published"],
        portrait=portrait,
        photos=photos,
        videos=videos,
    )


async def get_memorial(
    db: AsyncSession,
    settings: Settings,
    memorial_id: uuid.UUID,
    user: User | None,
    *,
    public_only: bool = False,
) -> MemorialOut:
    row = await sp_one(db, "SELECT * FROM sp_get_memorial(:id)", {"id": memorial_id})
    if row is None:
        raise HTTPException(status_code=404, detail="MEMORIAL_NOT_FOUND")

    if public_only:
        if not row["is_published"]:
            raise HTTPException(status_code=404, detail="MEMORIAL_NOT_PUBLISHED")
    elif user is not None:
        if row["owner_user_id"] != user.id and user.role.code != "admin":
            raise HTTPException(status_code=403, detail="FORBIDDEN")

    media_rows = await sp_all(
        db,
        "SELECT * FROM sp_get_memorial_media(:memorial_id)",
        {"memorial_id": memorial_id},
    )
    return _build_memorial_out(settings, row, media_rows)


async def list_user_memorials(db: AsyncSession, settings: Settings, user: User) -> list[MemorialOut]:
    id_rows = await sp_all(
        db,
        "SELECT * FROM sp_list_memorial_ids_by_owner(:user_id)",
        {"user_id": user.id},
    )

    result = []
    for row in id_rows:
        memorial = await get_memorial(db, settings, row["id"], user)
        result.append(memorial)
    return result


async def save_media_record(
    db: AsyncSession,
    settings: Settings,
    user: User,
    memorial_id: uuid.UUID,
    media_type_code: str,
    storage_key: str,
    mime_type: str,
    size_bytes: int,
    original_filename: str,
    duration_seconds: int | None = None,
) -> MemorialMediaItem:
    await _assert_owner(db, memorial_id, user)

    if media_type_code == "portrait":
        old_rows = await sp_all(
            db,
            "SELECT * FROM sp_list_portrait_media(:memorial_id)",
            {"memorial_id": memorial_id},
        )
        for old in old_rows:
            from app.services.media_storage import delete_file

            delete_file(settings, old["storage_key"])
            await call_sp(
                db,
                "SELECT sp_soft_delete_media(:id)",
                {"id": old["id"]},
            )

    media_type_id = await _lookup_media_type_id(db, media_type_code)
    processing_status_id = await _lookup_processing_status_id(db)

    sort_order = 0
    if media_type_code == "photo":
        sort_order = await sp_scalar(
            db,
            "SELECT sp_count_memorial_photos(:memorial_id)",
            {"memorial_id": memorial_id},
        ) or 0

    file_id = uuid.uuid4()
    try:
        await call_sp(
            db,
            """
            SELECT sp_insert_media_file(
                :id, :memorial_id, :media_type_id, :processing_status_id,
                :uploaded_by_user_id, :storage_bucket, :storage_key,
                :original_filename, :mime_type, :size_bytes, :duration_seconds, :sort_order
            )
            """,
            {
                "id": file_id,
                "memorial_id": memorial_id,
                "media_type_id": media_type_id,
                "processing_status_id": processing_status_id,
                "uploaded_by_user_id": user.id,
                "storage_bucket": settings.media_storage_bucket,
                "storage_key": storage_key,
                "original_filename": original_filename,
                "mime_type": mime_type,
                "size_bytes": size_bytes,
                "duration_seconds": duration_seconds,
                "sort_order": sort_order,
            },
        )
    except Exception as exc:
        err = str(getattr(exc, "orig", exc))
        if "PHOTO_LIMIT_REACHED" in err or "PHOTO_LIMIT_EXCEEDED" in err:
            raise HTTPException(status_code=400, detail="PHOTO_LIMIT_REACHED") from exc
        raise

    await db.commit()

    return MemorialMediaItem(
        id=file_id,
        storage_key=storage_key,
        url=_media_url(settings, storage_key),
        mime_type=mime_type,
        size_bytes=size_bytes,
        original_filename=original_filename,
        duration_seconds=duration_seconds,
        sort_order=sort_order,
    )


async def delete_media_file(
    db: AsyncSession,
    settings: Settings,
    user: User,
    media_id: uuid.UUID,
) -> None:
    row = await sp_one(
        db,
        "SELECT * FROM sp_get_media_for_delete(:id)",
        {"id": media_id},
    )
    if row is None:
        raise HTTPException(status_code=404, detail="MEDIA_NOT_FOUND")
    if row["owner_user_id"] != user.id and user.role.code != "admin":
        raise HTTPException(status_code=403, detail="FORBIDDEN")

    from app.services.media_storage import delete_file

    delete_file(settings, row["storage_key"])
    await call_sp(db, "SELECT sp_soft_delete_media(:id)", {"id": media_id})
    await db.commit()
