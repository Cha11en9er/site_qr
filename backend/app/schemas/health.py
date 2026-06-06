from pydantic import BaseModel


class HealthOut(BaseModel):
    status: str
    service: str


class DbHealthOut(BaseModel):
    status: str
    database: str
    package_types_count: int | None = None
    detail: str | None = None
