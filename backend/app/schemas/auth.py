from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    login: EmailStr = Field(description="Email")
    password: str = Field(min_length=4, max_length=128)
    accept_privacy: bool = Field(description="Согласие с политикой конфиденциальности")


class LoginRequest(BaseModel):
    login: EmailStr = Field(description="Email")
    password: str = Field(min_length=4, max_length=128)


class UserProfileUpdate(BaseModel):
    full_name: str | None = Field(default=None, max_length=256)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=20)


class UserOut(BaseModel):
    id: UUID
    email: str | None
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
