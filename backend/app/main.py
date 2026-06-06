from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import get_settings


@asynccontextmanager
async def lifespan(_app: FastAPI):
    yield


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="QR Память API",
        description="Backend для мемориальных QR-страниц",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router, prefix="/api/v1")

    @app.get("/", tags=["root"])
    async def root() -> dict[str, str]:
        return {
            "service": "qr-pamyat-api",
            "docs": "/docs",
            "health": "/api/v1/health",
        }

    return app


app = create_app()
