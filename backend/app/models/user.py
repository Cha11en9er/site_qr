from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import INET
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(primary_key=True)
    role_id: Mapped[int] = mapped_column(ForeignKey("user_roles.id"))
    email: Mapped[str] = mapped_column(String)
    phone: Mapped[str | None] = mapped_column(String(20))
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str | None] = mapped_column(String(256))
    is_active: Mapped[bool] = mapped_column(default=True)
    email_verified: Mapped[bool] = mapped_column(default=False)
    must_change_password: Mapped[bool] = mapped_column(default=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    role: Mapped["UserRole"] = relationship("UserRole", lazy="joined")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[UUID] = mapped_column(primary_key=True)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    token_hash: Mapped[str] = mapped_column(String(128))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    user_agent: Mapped[str | None] = mapped_column(String(512))
    ip_address: Mapped[str | None] = mapped_column(INET)


from app.models.lookups import UserRole  # noqa: E402
