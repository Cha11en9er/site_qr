"""Вызов хранимых функций PostgreSQL с именованными параметрами."""

from __future__ import annotations

from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def call_sp(db: AsyncSession, sql: str, params: dict[str, Any] | None = None):
    """Execute `SELECT * FROM sp_...(...)` or similar; returns Result."""
    return await db.execute(text(sql), params or {})


async def sp_scalar(db: AsyncSession, sql: str, params: dict[str, Any] | None = None) -> Any:
    result = await call_sp(db, sql, params)
    row = result.first()
    return row[0] if row else None


async def sp_one(db: AsyncSession, sql: str, params: dict[str, Any] | None = None) -> dict | None:
    result = await call_sp(db, sql, params)
    row = result.mappings().first()
    return dict(row) if row else None


async def sp_all(db: AsyncSession, sql: str, params: dict[str, Any] | None = None) -> list[dict]:
    result = await call_sp(db, sql, params)
    return [dict(row) for row in result.mappings().all()]
