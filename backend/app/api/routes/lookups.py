from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.lookups import (
    FulfillmentStatus,
    MediaProcessingStatus,
    MediaType,
    NotificationType,
    OrderStatus,
    PaymentStatus,
    QrCodeStatus,
    ReviewModerationStatus,
    UserRole,
)
from app.schemas.lookups import AllLookupsOut, LookupItem, TerminalLookupItem

router = APIRouter()


async def _fetch_lookup(db: AsyncSession, model, terminal: bool = False):
    rows = (await db.scalars(select(model).order_by(model.id))).all()
    if terminal:
        return [TerminalLookupItem.model_validate(row) for row in rows]
    return [LookupItem.model_validate(row) for row in rows]


@router.get("", response_model=AllLookupsOut)
async def get_all_lookups(db: AsyncSession = Depends(get_db)) -> AllLookupsOut:
    return AllLookupsOut(
        user_roles=await _fetch_lookup(db, UserRole),
        order_statuses=await _fetch_lookup(db, OrderStatus, terminal=True),
        payment_statuses=await _fetch_lookup(db, PaymentStatus, terminal=True),
        qr_code_statuses=await _fetch_lookup(db, QrCodeStatus),
        fulfillment_statuses=await _fetch_lookup(db, FulfillmentStatus),
        media_types=await _fetch_lookup(db, MediaType),
        media_processing_statuses=await _fetch_lookup(db, MediaProcessingStatus),
        review_moderation_statuses=await _fetch_lookup(db, ReviewModerationStatus),
        notification_types=await _fetch_lookup(db, NotificationType),
    )


@router.get("/user-roles", response_model=list[LookupItem])
async def get_user_roles(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, UserRole)


@router.get("/order-statuses", response_model=list[TerminalLookupItem])
async def get_order_statuses(db: AsyncSession = Depends(get_db)) -> list[TerminalLookupItem]:
    return await _fetch_lookup(db, OrderStatus, terminal=True)


@router.get("/payment-statuses", response_model=list[TerminalLookupItem])
async def get_payment_statuses(db: AsyncSession = Depends(get_db)) -> list[TerminalLookupItem]:
    return await _fetch_lookup(db, PaymentStatus, terminal=True)


@router.get("/qr-code-statuses", response_model=list[LookupItem])
async def get_qr_code_statuses(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, QrCodeStatus)


@router.get("/fulfillment-statuses", response_model=list[LookupItem])
async def get_fulfillment_statuses(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, FulfillmentStatus)


@router.get("/media-types", response_model=list[LookupItem])
async def get_media_types(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, MediaType)


@router.get("/media-processing-statuses", response_model=list[LookupItem])
async def get_media_processing_statuses(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, MediaProcessingStatus)


@router.get("/review-moderation-statuses", response_model=list[LookupItem])
async def get_review_moderation_statuses(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, ReviewModerationStatus)


@router.get("/notification-types", response_model=list[LookupItem])
async def get_notification_types(db: AsyncSession = Depends(get_db)) -> list[LookupItem]:
    return await _fetch_lookup(db, NotificationType)
