from __future__ import annotations

import base64
from decimal import Decimal
from typing import Any

import httpx


class YooKassaError(Exception):
    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class YooKassaService:
    API_URL = "https://api.yookassa.ru/v3"

    def __init__(self, shop_id: str, secret_key: str) -> None:
        self.shop_id = shop_id
        self.secret_key = secret_key

    def _auth_header(self) -> str:
        credentials = f"{self.shop_id}:{self.secret_key}".encode()
        return "Basic " + base64.b64encode(credentials).decode()

    async def create_payment(
        self,
        *,
        amount_rub: Decimal,
        description: str,
        idempotence_key: str,
        return_url: str,
        metadata: dict[str, str],
    ) -> dict[str, Any]:
        payload = {
            "amount": {"value": f"{amount_rub:.2f}", "currency": "RUB"},
            "capture": True,
            "confirmation": {"type": "redirect", "return_url": return_url},
            "description": description[:128],
            "metadata": metadata,
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.API_URL}/payments",
                headers={
                    "Authorization": self._auth_header(),
                    "Idempotence-Key": idempotence_key,
                    "Content-Type": "application/json",
                },
                json=payload,
            )

        if response.status_code not in (200, 201):
            raise YooKassaError(response.text, response.status_code)

        return response.json()
