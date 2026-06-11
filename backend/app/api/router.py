from fastapi import APIRouter

from app.api.routes import auth, health, lookups, media, memorials, orders, packages

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(packages.router, prefix="/packages", tags=["catalog"])
api_router.include_router(lookups.router, prefix="/lookups", tags=["lookups"])
api_router.include_router(orders.router, prefix="/orders", tags=["orders"])
api_router.include_router(memorials.router, prefix="/memorials", tags=["memorials"])
api_router.include_router(media.router, prefix="/media", tags=["media"])
