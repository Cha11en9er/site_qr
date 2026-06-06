from fastapi import APIRouter

from app.api.routes import auth, health, lookups, packages

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(packages.router, prefix="/packages", tags=["catalog"])
api_router.include_router(lookups.router, prefix="/lookups", tags=["lookups"])
