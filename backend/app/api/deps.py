"""Dependencies of the API. Tests replace them through app.dependency_overrides."""

from collections.abc import Callable
from datetime import date
from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from app import factory
from app.core.config import Settings, get_settings
from app.db.session import get_session
from app.providers.llm.base import LLMProvider
from app.providers.storage import FileStore


def get_llm(settings: Annotated[Settings, Depends(get_settings)]) -> LLMProvider:
    return factory.build_llm(settings)


def get_file_store(settings: Annotated[Settings, Depends(get_settings)]) -> FileStore:
    return factory.build_file_store(settings)


def get_today() -> Callable[[], date]:
    return date.today


SettingsDep = Annotated[Settings, Depends(get_settings)]
SessionDep = Annotated[Session, Depends(get_session)]
LLMDep = Annotated[LLMProvider, Depends(get_llm)]
FilesDep = Annotated[FileStore, Depends(get_file_store)]
TodayDep = Annotated[Callable[[], date], Depends(get_today)]
