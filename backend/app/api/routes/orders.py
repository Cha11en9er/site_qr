from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_optional_user
from app.core.config import get_settings
from app.core.database import get_db
from app.models.user import User
from app.schemas.orders import CheckoutRequest, CheckoutResponse, OrderStatusResponse
from app.services.orders import create_checkout, get_order_status

router = APIRouter()


@router.post("/checkout", response_model=CheckoutResponse)
async def checkout(
    payload: CheckoutRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User | None, Depends(get_optional_user)] = None,
) -> CheckoutResponse:
    settings = get_settings()
    result = await create_checkout(db, settings, payload, user)
    return CheckoutResponse(**result)


@router.get("/{order_id}/status", response_model=OrderStatusResponse)
async def order_status(
    order_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> OrderStatusResponse:
    result = await get_order_status(db, order_id)
    return OrderStatusResponse(**result)
