from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase

APP_SCHEMA = "qr"


class Base(DeclarativeBase):
    metadata = MetaData(schema=APP_SCHEMA)
