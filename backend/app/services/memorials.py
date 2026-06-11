from __future__ import annotations

import re
import secrets
import uuid
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.models.lookups import PackageType
from app.models.user import User
from app.schemas.memorials import MemorialCreate, MemorialMediaItem, MemorialOut, MemorialUpdate
from sqlalchemy import select

PACKAGE_CODE_MAP = {
    "standard": "standard",
    "premium": "premium",
    "max": "maximum",
}

MEDIA_TYPE_FOLDER = {
    "portrait": "portrait",
    "photo": "photos",
    "video": "videos",
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
    row = (
        await db.execute(text("SELECT id FROM media_types WHERE code = :code"), {"code": code})
    ).first()
    if row is None:
        raise HTTPException(status_code=500, detail=f"MEDIA_TYPE_{code}_NOT_FOUND")
    return row[0]


async def _lookup_processing_status_id(db: AsyncSession, code: str = "ready") -> int:
    row = (
        await db.execute(
            text("SELECT id FROM media_processing_statuses WHERE code = :code"),
            {"code": code},
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=500, detail="MEDIA_STATUS_NOT_FOUND")
    return row[0]


async def create_memorial(
    db: AsyncSession,
    settings: Settings,
    user: User,
    payload: MemorialCreate,
) -> MemorialOut:
    package = await _get_package(db, payload.package_type)
    memorial_id = uuid.uuid4()
    slug = _slug_from_name(payload.full_name)

    await db.execute(
        text(
            """
            INSERT INTO memorials (
                id, owner_user_id, public_slug, deceased_full_name,
                birth_date, death_date, father_full_name, mother_full_name, epitaph,
                package_type_id, max_photos, max_video_seconds, is_published
            ) VALUES (
                :id, :owner_user_id, :public_slug, :deceased_full_name,
                :birth_date, :death_date, :father_full_name, :mother_full_name, :epitaph,
                :package_type_id, :max_photos, :max_video_seconds, FALSE
            )
            """
        ),
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
    row = (
        await db.execute(
            text(
                """
                SELECT owner_user_id FROM memorials
                WHERE id = :id AND deleted_at IS NULL
                """
            ),
            {"id": memorial_id},
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="MEMORIAL_NOT_FOUND")
    if row[0] != user.id and user.role.code != "admin":
        raise HTTPException(status_code=403, detail="FORBIDDEN")


async def update_memorial(
    db: AsyncSession,
    settings: Settings,
    memorial_id: uuid.UUID,
    user: User,
    payload: MemorialUpdate,
) -> MemorialOut:
    await _assert_owner(db, memorial_id, user)

    fields = []
    params: dict = {"id": memorial_id}

    mapping = {
        "full_name": ("deceased_full_name", payload.full_name),
        "birth_date": ("birth_date", payload.birth_date),
        "death_date": ("death_date", payload.death_date),
        "father_name": ("father_full_name", payload.father_name),
        "mother_name": ("mother_full_name", payload.mother_name),
        "epitaph": ("epitaph", payload.epitaph),
        "grave_address": ("grave_location_label", payload.grave_address),
        "grave_lat": ("grave_latitude", payload.grave_lat),
        "grave_lng": ("grave_longitude", payload.grave_lng),
        "is_published": ("is_published", payload.is_published),
    }

    for key, (column, value) in mapping.items():
        if value is not None:
            fields.append(f"{column} = :{key}")
            params[key] = value

    if fields:
        fields.append("updated_at = now()")
        if payload.is_published is True:
            fields.append("published_at = COALESCE(published_at, now())")
        await db.execute(
            text(f"UPDATE memorials SET {', '.join(fields)} WHERE id = :id"),
            params,
        )
        await db.commit()

    return await get_memorial(db, settings, memorial_id, user)


async def _fetch_media_rows(db: AsyncSession, memorial_id: uuid.UUID) -> list[dict]:
    rows = (
        await db.execute(
            text(
                """
                SELECT mf.id, mf.storage_key, mf.mime_type, mf.size_bytes,
                       mf.original_filename, mf.duration_seconds, mf.sort_order,
                       mt.code AS media_type
                FROM media_files mf
                JOIN media_types mt ON mt.id = mf.media_type_id
                WHERE mf.memorial_id = :memorial_id AND mf.deleted_at IS NULL
                ORDER BY mf.sort_order, mf.created_at
                """
            ),
            {"memorial_id": memorial_id},
        )
    ).mappings().all()
    return [dict(row) for row in rows]


async def _memorial_row(db: AsyncSession, memorial_id: uuid.UUID) -> dict | None:
    row = (
        await db.execute(
            text(
                """
                SELECT m.id, m.public_slug, m.deceased_full_name AS full_name,
                       m.birth_date, m.death_date,
                       m.father_full_name AS father_name,
                       m.mother_full_name AS mother_name,
                       m.epitaph,
                       m.grave_location_label AS grave_address,
                       m.grave_latitude AS grave_lat,
                       m.grave_longitude AS grave_lng,
                       m.max_photos, m.max_video_seconds, m.is_published,
                       pt.code AS package_code
                FROM memorials m
                JOIN package_types pt ON pt.id = m.package_type_id
                WHERE m.id = :id AND m.deleted_at IS NULL
                """
            ),
            {"id": memorial_id},
        )
    ).mappings().first()
    return dict(row) if row else None


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
    row = await _memorial_row(db, memorial_id)
    if row is None:
        raise HTTPException(status_code=404, detail="MEMORIAL_NOT_FOUND")

    if public_only:
        if not row["is_published"]:
            raise HTTPException(status_code=404, detail="MEMORIAL_NOT_PUBLISHED")
    elif user is not None:
        owner_id = (
            await db.execute(
                text("SELECT owner_user_id FROM memorials WHERE id = :id"),
                {"id": memorial_id},
            )
        ).scalar_one()
        if owner_id != user.id and user.role.code != "admin":
            raise HTTPException(status_code=403, detail="FORBIDDEN")

    media_rows = await _fetch_media_rows(db, memorial_id)
    return _build_memorial_out(settings, row, media_rows)


async def list_user_memorials(db: AsyncSession, settings: Settings, user: User) -> list[MemorialOut]:
    ids = (
        await db.execute(
            text(
                """
                SELECT id FROM memorials
                WHERE owner_user_id = :user_id AND deleted_at IS NULL
                ORDER BY created_at DESC
                """
            ),
            {"user_id": user.id},
        )
    ).scalars().all()

    result = []
    for memorial_id in ids:
        row = await _memorial_row(db, memorial_id)
        if row:
            media_rows = await _fetch_media_rows(db, memorial_id)
            result.append(_build_memorial_out(settings, row, media_rows))
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
        old_rows = (
            await db.execute(
                text(
                    """
                    SELECT mf.id, mf.storage_key
                    FROM media_files mf
                    JOIN media_types mt ON mt.id = mf.media_type_id
                    WHERE mf.memorial_id = :memorial_id
                      AND mt.code = 'portrait'
                      AND mf.deleted_at IS NULL
                    """
                ),
                {"memorial_id": memorial_id},
            )
        ).mappings().all()
        for old in old_rows:
            from app.services.media_storage import delete_file

            delete_file(settings, old["storage_key"])
            await db.execute(
                text("UPDATE media_files SET deleted_at = now() WHERE id = :id"),
                {"id": old["id"]},
            )

    media_type_id = await _lookup_media_type_id(db, media_type_code)
    processing_status_id = await _lookup_processing_status_id(db)

    if media_type_code == "photo":
        count = (
            await db.execute(
                text(
                    """
                    SELECT COUNT(*) FROM media_files mf
                    JOIN media_types mt ON mt.id = mf.media_type_id
                    WHERE mf.memorial_id = :memorial_id
                      AND mt.code = 'photo'
                      AND mf.deleted_at IS NULL
                    """
                ),
                {"memorial_id": memorial_id},
            )
        ).scalar_one()
        limits = (
            await db.execute(
                text("SELECT max_photos FROM memorials WHERE id = :id"),
                {"id": memorial_id},
            )
        ).scalar_one()
        if count >= limits:
            raise HTTPException(status_code=400, detail="PHOTO_LIMIT_REACHED")

    file_id = uuid.uuid4()
    sort_order = 0
    if media_type_code == "photo":
        sort_order = (
            await db.execute(
                text(
                    """
                    SELECT COUNT(*) FROM media_files mf
                    JOIN media_types mt ON mt.id = mf.media_type_id
                    WHERE mf.memorial_id = :memorial_id
                      AND mt.code = 'photo'
                      AND mf.deleted_at IS NULL
                    """
                ),
                {"memorial_id": memorial_id},
            )
        ).scalar_one()

    await db.execute(
        text(
            """
            INSERT INTO media_files (
                id, memorial_id, media_type_id, processing_status_id,
                uploaded_by_user_id, storage_bucket, storage_key,
                original_filename, mime_type, size_bytes, duration_seconds, sort_order
            ) VALUES (
                :id, :memorial_id, :media_type_id, :processing_status_id,
                :uploaded_by_user_id, :storage_bucket, :storage_key,
                :original_filename, :mime_type, :size_bytes, :duration_seconds, :sort_order
            )
            """
        ),
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
    row = (
        await db.execute(
            text(
                """
                SELECT mf.storage_key, m.owner_user_id
                FROM media_files mf
                JOIN memorials m ON m.id = mf.memorial_id
                WHERE mf.id = :id AND mf.deleted_at IS NULL
                """
            ),
            {"id": media_id},
        )
    ).mappings().first()
    if row is None:
        raise HTTPException(status_code=404, detail="MEDIA_NOT_FOUND")
    if row["owner_user_id"] != user.id and user.role.code != "admin":
        raise HTTPException(status_code=403, detail="FORBIDDEN")

    from app.services.media_storage import delete_file

    delete_file(settings, row["storage_key"])
    await db.execute(
        text("UPDATE media_files SET deleted_at = now() WHERE id = :id"),
        {"id": media_id},
    )
    await db.commit()
