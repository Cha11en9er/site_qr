from datetime import date
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


PackageCode = Literal["standard", "premium", "max"]


class MemorialMediaItem(BaseModel):
    id: UUID
    storage_key: str
    url: str
    mime_type: str
    size_bytes: int
    original_filename: str
    duration_seconds: int | None = None
    sort_order: int


class MemorialCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=256)
    birth_date: date
    death_date: date
    father_name: str | None = None
    mother_name: str | None = None
    epitaph: str | None = None
    package_type: PackageCode = "standard"


class MemorialUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=256)
    birth_date: date | None = None
    death_date: date | None = None
    father_name: str | None = None
    mother_name: str | None = None
    epitaph: str | None = None
    grave_address: str | None = None
    grave_lat: Decimal | None = None
    grave_lng: Decimal | None = None
    is_published: bool | None = None


class MemorialOut(BaseModel):
    id: UUID
    public_slug: str
    full_name: str
    birth_date: date | None
    death_date: date | None
    father_name: str | None
    mother_name: str | None
    epitaph: str | None
    grave_address: str | None
    grave_lat: Decimal | None
    grave_lng: Decimal | None
    package_type: str
    max_photos: int
    max_video_seconds: int
    is_published: bool
    portrait: MemorialMediaItem | None = None
    photos: list[MemorialMediaItem] = []
    videos: list[MemorialMediaItem] = []
