from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=4, max_length=128)
    full_name: str = Field(min_length=2, max_length=256)
    phone: str = Field(min_length=10, max_length=20)
    accept_privacy: bool = Field(description="Согласие с политикой конфиденциальности")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=4, max_length=128)


class UserOut(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str | None
    phone: str | None
    role: str
    is_admin: bool
    email_verified: bool
    must_change_password: bool


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthResponse(BaseModel):
    user: UserOut
    tokens: TokenPair


class LogoutRequest(BaseModel):
    refresh_token: str


class MessageResponse(BaseModel):
    message: str
    detail: str | None = None
