from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_client_meta, get_current_user_out
from app.core.database import get_db
from app.models.user import User
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    RegisterRequest,
    UserOut,
)
from app.services.auth import login_user, register_user, revoke_refresh_token

router = APIRouter()


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    body: RegisterRequest,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AuthResponse:
    if not body.accept_privacy:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Privacy policy consent is required",
        )

    user_agent, ip_address = get_client_meta(request)
    return await register_user(
        db,
        email=body.email,
        password=body.password,
        full_name=body.full_name,
        phone=body.phone,
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.post("/login", response_model=AuthResponse)
async def login(
    body: LoginRequest,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AuthResponse:
    user_agent, ip_address = get_client_meta(request)
    return await login_user(
        db,
        email=body.email,
        password=body.password,
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.get("/me", response_model=UserOut)
async def me(current_user: Annotated[UserOut, Depends(get_current_user_out)]) -> UserOut:
    return current_user


@router.post("/logout", response_model=MessageResponse)
async def logout(
    body: LogoutRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> MessageResponse:
    await revoke_refresh_token(db, body.refresh_token)
    return MessageResponse(message="logged_out")
