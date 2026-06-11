from uuid import UUID

from pydantic import BaseModel


class MediaUploadResponse(BaseModel):
    id: UUID
    storage_key: str
    url: str
    mime_type: str
    size_bytes: int
    original_filename: str
    media_type: str
