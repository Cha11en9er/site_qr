from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import TokenValidationError, parse_access_token
from app.models.user import User
from app.schemas.auth import UserOut
from app.services.auth import get_user_by_id, user_to_out

bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    db: Annotated[AsyncSession, Depends(get_db)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="NOT_AUTHENTICATED")

    try:
        user_id, _role = parse_access_token(credentials.credentials)
    except TokenValidationError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="INVALID_TOKEN") from exc

    user = await get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="USER_NOT_FOUND")

    await db.refresh(user, attribute_names=["role"])
    return user


async def get_current_user_out(
    user: Annotated[User, Depends(get_current_user)],
) -> UserOut:
    return user_to_out(user)


def get_client_meta(request: Request) -> tuple[str | None, str | None]:
    user_agent = request.headers.get("user-agent")
    forwarded = request.headers.get("x-forwarded-for")
    ip_address = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else None)
    return user_agent, ip_address
