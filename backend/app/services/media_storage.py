from __future__ import annotations

import re
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import HTTPException, UploadFile

from app.core.config import Settings

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/webm", "video/quicktime"}
MAX_IMAGE_BYTES = 15 * 1024 * 1024
MAX_VIDEO_BYTES = 100 * 1024 * 1024

EXT_BY_MIME = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",
}

# Новый формат: YYYY-MM/{order_id|memorial_id}/{portrait|photos|videos}/{file}.ext
# Legacy: memorials/{memorial_id}/...
# Статические примеры: examples/{slug}/...
STORAGE_KEY_PATTERNS = (
    r"\d{4}-\d{2}/[0-9a-f-]{36}/(portrait|photos|videos)/[0-9a-f-]{36}\.[a-z0-9]+",
    r"memorials/[0-9a-f-]{36}/[a-z]+/[0-9a-f-]{36}\.[a-z0-9]+",
    r"examples/[a-z]+/[a-z0-9_-]+\.(jpg|jpeg|png|webp)",
)


def normalize_storage_key(key: str) -> str:
    cleaned = key.replace("\\", "/").strip("/")
    if ".." in cleaned.split("/"):
        raise HTTPException(status_code=400, detail="INVALID_STORAGE_KEY")
    if not any(re.fullmatch(pattern, cleaned) for pattern in STORAGE_KEY_PATTERNS):
        raise HTTPException(status_code=400, detail="INVALID_STORAGE_KEY")
    return cleaned


def absolute_path(settings: Settings, storage_key: str) -> Path:
    key = normalize_storage_key(storage_key)
    root = settings.media_root_path
    full = (root / key).resolve()
    if not str(full).startswith(str(root.resolve())):
        raise HTTPException(status_code=400, detail="INVALID_STORAGE_KEY")
    return full


def current_storage_month() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m")


def build_storage_key(
    shard_id: uuid.UUID,
    media_folder: str,
    mime_type: str,
    *,
    month: str | None = None,
) -> str:
    """Путь: YYYY-MM/{shard_id}/{portrait|photos|videos}/{uuid}.ext

    shard_id — order_id, если мемориал привязан к QR заказа, иначе memorial_id.
    """
    ym = month or current_storage_month()
    ext = EXT_BY_MIME.get(mime_type, ".bin")
    return f"{ym}/{shard_id}/{media_folder}/{uuid.uuid4()}{ext}"


async def save_upload_file(
    settings: Settings,
    upload: UploadFile,
    storage_key: str,
    *,
    max_bytes: int,
    allowed_types: set[str],
) -> int:
    if not upload.content_type or upload.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="UNSUPPORTED_FILE_TYPE")

    key = normalize_storage_key(storage_key)
    dest = absolute_path(settings, key)
    dest.parent.mkdir(parents=True, exist_ok=True)

    size = 0
    try:
        with dest.open("wb") as out:
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > max_bytes:
                    raise HTTPException(status_code=400, detail="FILE_TOO_LARGE")
                out.write(chunk)
    except HTTPException:
        if dest.exists():
            dest.unlink()
        raise

    return size


def delete_file(settings: Settings, storage_key: str) -> None:
    path = absolute_path(settings, storage_key)
    if path.exists():
        path.unlink()
