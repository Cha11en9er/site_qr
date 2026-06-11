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
    parse_email_login,
    verify_password,
)
from app.db.procedures import call_sp, sp_scalar
from app.models.lookups import UserRole
from app.models.user import RefreshToken, User
from app.schemas.auth import AuthResponse, TokenPair, UserOut, UserProfileUpdate


def user_to_out(user: User) -> UserOut:
    role_code = user.role.code if user.role else "buyer"
    return UserOut(
        id=user.id,
        email=str(user.email) if user.email else None,
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


def _login_http_error(exc: ValueError) -> HTTPException:
    code = str(exc)
    if code == "INVALID_PHONE":
        return HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Phone must be in format +79001234567",
        )
    if code in {"INVALID_LOGIN", "LOGIN_REQUIRED"}:
        return HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="INVALID_LOGIN",
        )
    return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=code)


async def _find_user_by_email(db: AsyncSession, login: str) -> User | None:
    try:
        email = parse_email_login(login)
    except ValueError as exc:
        raise _login_http_error(exc) from exc

    return await db.scalar(
        select(User)
        .where(User.email == email, User.deleted_at.is_(None))
        .options(selectinload(User.role))
    )


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
    refresh_id = uuid4()

    await call_sp(
        db,
        """
        SELECT sp_insert_refresh_token(
            :id, :user_id, :token_hash, :expires_at, :user_agent, :ip_address
        )
        """,
        {
            "id": refresh_id,
            "user_id": user.id,
            "token_hash": hash_token(refresh_value),
            "expires_at": get_refresh_token_expiry(),
            "user_agent": user_agent,
            "ip_address": ip_address,
        },
    )
    await db.commit()
    return TokenPair(access_token=access_token, refresh_token=refresh_value)


async def register_user(
    db: AsyncSession,
    *,
    login: str,
    password: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> AuthResponse:
    try:
        email = parse_email_login(login)
    except ValueError as exc:
        raise _login_http_error(exc) from exc

    if await sp_scalar(db, "SELECT sp_user_email_exists(:email)", {"email": email}):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="LOGIN_ALREADY_EXISTS")

    buyer_role_id = await _get_role_id(db, "buyer")
    user_id = uuid4()

    try:
        await call_sp(
            db,
            """
            SELECT sp_register_user(
                :id, :role_id, :email, :phone, :password_hash, :full_name
            )
            """,
            {
                "id": user_id,
                "role_id": buyer_role_id,
                "email": email,
                "phone": None,
                "password_hash": hash_password(password),
                "full_name": None,
            },
        )
        await db.commit()
    except Exception as exc:
        await db.rollback()
        err = str(getattr(exc, "orig", exc))
        if "LOGIN_ALREADY_EXISTS" in err or "EMAIL_ALREADY_EXISTS" in err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="LOGIN_ALREADY_EXISTS",
            ) from exc
        raise

    user = await db.scalar(
        select(User)
        .where(User.id == user_id)
        .options(selectinload(User.role))
    )
    if user is None:
        raise HTTPException(status_code=500, detail="USER_CREATE_FAILED")

    tokens = await _issue_tokens(db, user, user_agent=user_agent, ip_address=ip_address)
    return AuthResponse(user=user_to_out(user), tokens=tokens)


async def login_user(
    db: AsyncSession,
    *,
    login: str,
    password: str,
    user_agent: str | None = None,
    ip_address: str | None = None,
) -> AuthResponse:
    user = await _find_user_by_email(db, login)
    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="INVALID_CREDENTIALS")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="ACCOUNT_DISABLED")

    await call_sp(db, "SELECT sp_update_last_login(:user_id)", {"user_id": user.id})
    await db.flush()
    await db.refresh(user, attribute_names=["role"])

    tokens = await _issue_tokens(db, user, user_agent=user_agent, ip_address=ip_address)
    return AuthResponse(user=user_to_out(user), tokens=tokens)


async def update_user_profile(
    db: AsyncSession,
    *,
    user_id: UUID,
    payload: UserProfileUpdate,
) -> UserOut:
    fields_set = payload.model_fields_set
    if not fields_set:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="NO_FIELDS_TO_UPDATE")

    normalized_phone: str | None = None
    if "phone" in fields_set and payload.phone is not None:
        try:
            normalized_phone = normalize_phone(payload.phone)
        except ValueError as exc:
            raise _login_http_error(exc) from exc

    try:
        await call_sp(
            db,
            """
            SELECT sp_update_user_profile(
                :user_id,
                :set_full_name, :full_name,
                :set_email, :email,
                :set_phone, :phone
            )
            """,
            {
                "user_id": user_id,
                "set_full_name": "full_name" in fields_set,
                "full_name": payload.full_name,
                "set_email": "email" in fields_set,
                "email": str(payload.email).lower() if payload.email else None,
                "set_phone": "phone" in fields_set,
                "phone": normalized_phone,
            },
        )
    except Exception as exc:
        err = str(getattr(exc, "orig", exc))
        if "EMAIL_ALREADY_EXISTS" in err:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="EMAIL_ALREADY_EXISTS") from exc
        if "PHONE_ALREADY_EXISTS" in err:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="PHONE_ALREADY_EXISTS") from exc
        if "EMAIL_OR_PHONE_REQUIRED" in err:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="EMAIL_OR_PHONE_REQUIRED",
            ) from exc
        raise

    await db.commit()

    user = await db.scalar(
        select(User)
        .where(User.id == user_id, User.deleted_at.is_(None))
        .options(selectinload(User.role))
    )
    if user is None:
        raise HTTPException(status_code=404, detail="USER_NOT_FOUND")
    return user_to_out(user)


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    return await db.scalar(
        select(User).where(User.id == user_id, User.deleted_at.is_(None), User.is_active.is_(True))
    )


async def revoke_refresh_token(db: AsyncSession, refresh_token: str) -> None:
    from app.core.security import verify_token_hash

    tokens = (await db.scalars(select(RefreshToken).where(RefreshToken.revoked_at.is_(None)))).all()
    for row in tokens:
        if verify_token_hash(refresh_token, row.token_hash):
            await call_sp(
                db,
                "SELECT sp_revoke_refresh_token_by_hash(:token_hash)",
                {"token_hash": row.token_hash},
            )
            await db.commit()
            return
