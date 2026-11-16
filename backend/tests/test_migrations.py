from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect

from app.core.config import get_settings
from app.db.models import Base
from app.db.session import get_engine, get_session_factory

BACKEND = Path(__file__).resolve().parents[1]


def test_the_migrations_build_the_tables_the_models_describe(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A column added to a model without a migration, or the other way round, fails here."""
    url = f"sqlite:///{tmp_path / 'migrated.db'}"
    monkeypatch.setenv("DATABASE_URL", url)
    monkeypatch.setenv("LLM_PROVIDER", "fake")
    monkeypatch.setenv("LLM_MODEL", "any")
    caches = (get_settings, get_engine, get_session_factory)
    for cache in caches:
        cache.cache_clear()
    try:
        command.upgrade(Config(str(BACKEND / "alembic.ini")), "head")
    finally:
        get_engine().dispose()
        for cache in caches:
            cache.cache_clear()

    engine = create_engine(url)
    inspector = inspect(engine)
    for table in Base.metadata.tables.values():
        migrated = {column["name"]: column for column in inspector.get_columns(table.name)}
        assert set(migrated) == {column.name for column in table.columns}
        for column in table.columns:
            assert migrated[column.name]["nullable"] == column.nullable, column.name
        expected_indexes = {index.name for index in table.indexes}
        assert {index["name"] for index in inspector.get_indexes(table.name)} == expected_indexes
    engine.dispose()
