from datetime import datetime
from decimal import Decimal

from pydantic import Field

from app.schemas.common import ORMModel


class LookupItem(ORMModel):
    id: int
    code: str
    name: str


class TerminalLookupItem(LookupItem):
    is_terminal: bool


class PackageTypeOut(ORMModel):
    id: int
    code: str
    name: str
    price_rub: Decimal
    max_photos: int
    max_video_seconds: int
    is_active: bool
    sort_order: int
    created_at: datetime

    @property
    def max_video_minutes(self) -> int:
        return self.max_video_seconds // 60


class PackageTypePublic(ORMModel):
    id: int
    code: str
    name: str
    price_rub: Decimal
    max_photos: int
    max_video_seconds: int
    max_video_minutes: int = Field(description="Удобное поле: секунды / 60")


class AllLookupsOut(ORMModel):
    user_roles: list[LookupItem]
    order_statuses: list[TerminalLookupItem]
    payment_statuses: list[TerminalLookupItem]
    qr_code_statuses: list[LookupItem]
    fulfillment_statuses: list[LookupItem]
    media_types: list[LookupItem]
    media_processing_statuses: list[LookupItem]
    review_moderation_statuses: list[LookupItem]
    notification_types: list[LookupItem]
