from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import (
    create_access_token,
    create_refresh_token_value,
    get_refresh_token_expiry,
    hash_password,
    hash_token,
    normalize_phone,
    verify_password,
)
from app.models.lookups import UserRole
from app.models.user import RefreshToken, User
from app.schemas.auth import AuthResponse, TokenPair, UserOut


def user_to_out(user: User) -> UserOut:
    role_code = user.role.code if user.role else "buyer"
    return UserOut(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        phone=user.phone,
        role=role_code,
        is_admin=role_code == "admin",
        email_verified=user.email_verified,
        must_change_password=user.must_change_password,
    )


async def _get_role_id(db: AsyncSession, code: str) -> int:
    role_id = await db.scalar(select(UserRole.id).where(UserRole.code == code))
    if role_id is None:
        raise HTTPException(status_code=500, detail=f"Role '{code}' is not configured")
    return role_id


async def _issue_tokens(
    db: AsyncSession,
    user: User,
    *,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> TokenPair:
    role_code = user.role.code if user.role else "buyer"
    access_token = create_access_token(user.id, role_code)
    refresh_value = create_refresh_token_value()

    db.add(
        RefreshToken(
            id=uuid4(),
            user_id=user.id,
            token_hash=hash_token(refresh_value),
            expires_at=get_refresh_token_expiry(),
            user_agent=user_agent,
            ip_address=ip_address,
        )
    )
    await db.commit()
    return TokenPair(access_token=access_token, refresh_token=refresh_value)


async def register_user(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    full_name: str,
    phone: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> AuthResponse:
    existing = await db.scalar(
        select(User.id).where(User.email == email, User.deleted_at.is_(None))
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="EMAIL_ALREADY_EXISTS")

    try:
        normalized_phone = normalize_phone(phone)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Phone must be in format +79001234567",
        ) from exc

    buyer_role_id = await _get_role_id(db, "buyer")
    user = User(
        id=uuid4(),
        role_id=buyer_role_id,
        email=email.lower(),
        phone=normalized_phone,
        password_hash=hash_password(password),
        full_name=full_name.strip(),
        email_verified=False,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user, attribute_names=["role"])

    tokens = await _issue_tokens(db, user, user_agent=user_agent, ip_address=ip_address)
    return AuthResponse(user=user_to_out(user), tokens=tokens)


async def login_user(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> AuthResponse:
    user = await db.scalar(
        select(User)
        .where(User.email == email.lower(), User.deleted_at.is_(None))
        .options(selectinload(User.role))
    )
    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="INVALID_CREDENTIALS")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="ACCOUNT_DISABLED")

    user.last_login_at = datetime.now(UTC)
    await db.flush()
    await db.refresh(user, attribute_names=["role"])

    tokens = await _issue_tokens(db, user, user_agent=user_agent, ip_address=ip_address)
    return AuthResponse(user=user_to_out(user), tokens=tokens)


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    return await db.scalar(
        select(User).where(User.id == user_id, User.deleted_at.is_(None), User.is_active.is_(True))
    )


async def revoke_refresh_token(db: AsyncSession, refresh_token: str) -> None:
    from app.core.security import verify_token_hash

    tokens = (await db.scalars(select(RefreshToken).where(RefreshToken.revoked_at.is_(None)))).all()
    for row in tokens:
        if verify_token_hash(refresh_token, row.token_hash):
            row.revoked_at = datetime.now(UTC)
            await db.commit()
            return
