from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator
import re


PackageCode = Literal["standard", "premium", "max"]


class CheckoutRequest(BaseModel):
    package_type: PackageCode
    quantity: int = Field(ge=1, le=50)
    deceased_name: str = Field(min_length=2, max_length=256)
    email: EmailStr
    phone: str = Field(min_length=10, max_length=20)
    delivery_address: str = Field(min_length=10, max_length=2000)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        digits = re.sub(r"\D", "", value)
        if digits.startswith("8") and len(digits) == 11:
            digits = "7" + digits[1:]
        if len(digits) == 10:
            digits = "7" + digits
        if not re.fullmatch(r"7\d{10}", digits):
            raise ValueError("Введите корректный номер телефона")
        return f"+{digits}"


class CheckoutResponse(BaseModel):
    order_id: UUID
    payment_id: UUID
    confirmation_url: str
    amount_rub: Decimal


class OrderStatusResponse(BaseModel):
    order_id: UUID
    status: str
    is_paid: bool
    total_amount: Decimal
