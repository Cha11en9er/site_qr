from __future__ import annotations

import json
import uuid
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.db.procedures import call_sp, sp_all, sp_one, sp_scalar
from app.models.lookups import FulfillmentStatus, OrderStatus, PackageType, PaymentStatus
from app.models.user import User
from app.schemas.orders import CheckoutRequest
from app.services.yookassa import YooKassaError, YooKassaService


PACKAGE_CODE_MAP = {
    "standard": "standard",
    "premium": "premium",
    "max": "maximum",
}


async def _lookup_id(db: AsyncSession, model, code: str) -> int:
    item = await db.scalar(select(model).where(model.code == code))
    if item is None:
        raise HTTPException(status_code=500, detail=f"Lookup '{code}' not found in database")
    return item.id


async def create_checkout(
    db: AsyncSession,
    settings: Settings,
    payload: CheckoutRequest,
    user: User | None,
) -> dict:
    if not settings.yookassa_configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="YOOKASSA_NOT_CONFIGURED",
        )

    db_package_code = PACKAGE_CODE_MAP[payload.package_type]
    package = await db.scalar(
        select(PackageType).where(
            PackageType.code == db_package_code,
            PackageType.is_active.is_(True),
        )
    )
    if package is None:
        raise HTTPException(status_code=404, detail="PACKAGE_NOT_FOUND")

    pending_payment_status_id = await _lookup_id(db, OrderStatus, "pending_payment")
    waiting_payment_status_id = await _lookup_id(db, PaymentStatus, "waiting")
    fulfillment_pending_id = await _lookup_id(db, FulfillmentStatus, "pending")

    unit_price = Decimal(package.price_rub)
    total_amount = unit_price * payload.quantity
    order_id = uuid.uuid4()
    payment_id = uuid.uuid4()
    idempotence_key = uuid.uuid4()
    return_url = f"{settings.yookassa_return_url}?order_id={order_id}"

    await call_sp(
        db,
        """
        SELECT sp_create_checkout_order(
            :order_id, :user_id, :status_id, :buyer_email, :buyer_phone, :buyer_name,
            :total_amount, :package_type_id, :quantity, :unit_price_rub, :line_total_rub,
            :snapshot_max_photos, :snapshot_max_video_sec, :snapshot_package_name,
            :fulfillment_status_id, :delivery_address
        )
        """,
        {
            "order_id": order_id,
            "user_id": user.id if user else None,
            "status_id": pending_payment_status_id,
            "buyer_email": str(payload.email).lower(),
            "buyer_phone": payload.phone,
            "buyer_name": payload.deceased_name,
            "total_amount": total_amount,
            "package_type_id": package.id,
            "quantity": payload.quantity,
            "unit_price_rub": unit_price,
            "line_total_rub": total_amount,
            "snapshot_max_photos": package.max_photos,
            "snapshot_max_video_sec": package.max_video_seconds,
            "snapshot_package_name": package.name,
            "fulfillment_status_id": fulfillment_pending_id,
            "delivery_address": payload.delivery_address,
        },
    )

    yookassa = YooKassaService(settings.yookassa_shop_id, settings.yookassa_secret_key)
    description = f"QR Память — {package.name} × {payload.quantity}"

    try:
        payment_data = await yookassa.create_payment(
            amount_rub=total_amount,
            description=description,
            idempotence_key=str(idempotence_key),
            return_url=return_url,
            metadata={
                "order_id": str(order_id),
                "deceased_name": payload.deceased_name,
            },
        )
    except YooKassaError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"YOOKASSA_ERROR: {exc}",
        ) from exc

    provider_payment_id = payment_data.get("id")
    confirmation = payment_data.get("confirmation") or {}
    confirmation_url = confirmation.get("confirmation_url")
    if not provider_payment_id or not confirmation_url:
        raise HTTPException(status_code=502, detail="YOOKASSA_INVALID_RESPONSE")

    await call_sp(
        db,
        """
        SELECT sp_record_payment(
            :id, :order_id, :status_id, :provider_payment_id, :idempotence_key,
            :amount_rub, :confirmation_url
        )
        """,
        {
            "id": payment_id,
            "order_id": order_id,
            "status_id": waiting_payment_status_id,
            "provider_payment_id": provider_payment_id,
            "idempotence_key": idempotence_key,
            "amount_rub": total_amount,
            "confirmation_url": confirmation_url,
        },
    )

    await db.commit()

    return {
        "order_id": order_id,
        "payment_id": payment_id,
        "confirmation_url": confirmation_url,
        "amount_rub": total_amount,
    }


async def get_order_status(db: AsyncSession, order_id: uuid.UUID) -> dict:
    row = await sp_one(
        db,
        "SELECT * FROM sp_get_order_status(:order_id)",
        {"order_id": order_id},
    )

    if row is None:
        raise HTTPException(status_code=404, detail="ORDER_NOT_FOUND")

    is_paid = row["status_code"] == "paid" or row["paid_at"] is not None
    return {
        "order_id": row["order_id"],
        "status": row["status_code"],
        "is_paid": is_paid,
        "total_amount": row["total_amount"],
    }


async def process_yookassa_webhook(db: AsyncSession, event: dict) -> None:
    event_type = event.get("event")
    payment_object = event.get("object") or {}
    provider_payment_id = payment_object.get("id")
    provider_event_id = event.get("id") or provider_payment_id

    if not provider_payment_id or not provider_event_id:
        return

    exists = await sp_scalar(
        db,
        "SELECT sp_webhook_event_exists(:provider, :provider_event_id)",
        {"provider": "yookassa", "provider_event_id": provider_event_id},
    )
    if exists:
        return

    await call_sp(
        db,
        """
        SELECT sp_insert_webhook_event(
            :provider, :provider_event_id, :event_type, :provider_payment_id, :payload
        )
        """,
        {
            "provider": "yookassa",
            "provider_event_id": provider_event_id,
            "event_type": event_type or "unknown",
            "provider_payment_id": provider_payment_id,
            "payload": json.dumps(event),
        },
    )

    if event_type != "payment.succeeded":
        await db.commit()
        return

    await sp_all(
        db,
        "SELECT * FROM sp_apply_payment_succeeded(:provider_payment_id)",
        {"provider_payment_id": provider_payment_id},
    )

    await call_sp(
        db,
        """
        SELECT sp_mark_webhook_processed(:provider, :provider_event_id)
        """,
        {"provider": "yookassa", "provider_event_id": provider_event_id},
    )
    await db.commit()
