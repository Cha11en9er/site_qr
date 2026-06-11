from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.services.orders import process_yookassa_webhook

router = APIRouter()


@router.post("/yookassa")
async def yookassa_webhook(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    payload: dict[str, Any] = await request.json()
    await process_yookassa_webhook(db, payload)
    return {"status": "ok"}
