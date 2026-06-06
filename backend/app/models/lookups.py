from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, Integer, Numeric, SmallInteger, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserRole(Base):
    __tablename__ = "user_roles"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))


class PackageType(Base):
    __tablename__ = "package_types"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))
    price_rub: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    max_photos: Mapped[int] = mapped_column(Integer)
    max_video_seconds: Mapped[int] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(SmallInteger, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class OrderStatus(Base):
    __tablename__ = "order_statuses"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))
    is_terminal: Mapped[bool] = mapped_column(Boolean, default=False)


class PaymentStatus(Base):
    __tablename__ = "payment_statuses"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))
    is_terminal: Mapped[bool] = mapped_column(Boolean, default=False)


class QrCodeStatus(Base):
    __tablename__ = "qr_code_statuses"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))


class FulfillmentStatus(Base):
    __tablename__ = "fulfillment_statuses"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))


class MediaType(Base):
    __tablename__ = "media_types"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))


class MediaProcessingStatus(Base):
    __tablename__ = "media_processing_statuses"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))


class ReviewModerationStatus(Base):
    __tablename__ = "review_moderation_statuses"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(128))


class NotificationType(Base):
    __tablename__ = "notification_types"

    id: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    code: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(256))
