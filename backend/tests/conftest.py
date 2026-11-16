from collections.abc import Iterator
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.models import Base
from app.providers.storage import FileStore


@pytest.fixture
def session() -> Iterator[Session]:
    """A session on a throwaway in-memory database, so tests need no Docker or .env."""
    # StaticPool keeps one shared connection, so API tests see the same data from every thread.
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        yield session
    engine.dispose()


@pytest.fixture
def files(tmp_path: Path) -> FileStore:
    """A document store in a temporary folder."""
    return FileStore(tmp_path / "files")
