import re
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

import bcrypt
from jose import JWTError, jwt

from app.core.config import get_settings

PHONE_PATTERN = re.compile(r"^\+[0-9]{10,15}$")
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone)
    if digits.startswith("8") and len(digits) == 11:
        digits = "7" + digits[1:]
    if not digits.startswith("7") and len(digits) == 10:
        digits = "7" + digits
    normalized = f"+{digits}"
    if not PHONE_PATTERN.match(normalized):
        raise ValueError("INVALID_PHONE")
    return normalized


def parse_email_login(login: str) -> str:
    """Нормализованный email для входа и регистрации."""
    value = login.strip().lower()
    if not value:
        raise ValueError("LOGIN_REQUIRED")
    if not EMAIL_PATTERN.match(value):
        raise ValueError("INVALID_LOGIN")
    return value


def parse_login(login: str) -> tuple[str | None, str | None]:
    """Email или телефон (телефон — только в профиле, не при входе)."""
    value = login.strip()
    if not value:
        raise ValueError("LOGIN_REQUIRED")
    if "@" in value:
        return parse_email_login(value), None
    return None, normalize_phone(value)


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain_password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(plain_password.encode(), password_hash.encode())


def hash_token(token: str) -> str:
    return bcrypt.hashpw(token.encode(), bcrypt.gensalt()).decode()


def verify_token_hash(plain_token: str, token_hash: str) -> bool:
    return bcrypt.checkpw(plain_token.encode(), token_hash.encode())


def create_access_token(user_id: UUID, role_code: str) -> str:
    settings = get_settings()
    expire = datetime.now(UTC) + timedelta(minutes=settings.jwt_access_expire_minutes)
    payload = {
        "sub": str(user_id),
        "role": role_code,
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_access_token(token: str) -> dict:
    settings = get_settings()
    return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])


def create_refresh_token_value() -> str:
    return secrets.token_urlsafe(48)


def get_refresh_token_expiry() -> datetime:
    settings = get_settings()
    return datetime.now(UTC) + timedelta(days=settings.jwt_refresh_expire_days)


class TokenValidationError(Exception):
    pass


def parse_access_token(token: str) -> tuple[UUID, str]:
    try:
        payload = decode_access_token(token)
        if payload.get("type") != "access":
            raise TokenValidationError("INVALID_TOKEN_TYPE")
        user_id = UUID(payload["sub"])
        role = payload.get("role", "buyer")
        return user_id, role
    except (JWTError, KeyError, ValueError) as exc:
        raise TokenValidationError("INVALID_TOKEN") from exc
