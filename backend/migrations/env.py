"""Alembic environment: where migrations find the database and the table definitions."""

from logging.config import fileConfig

from alembic import context

from app.core.config import get_settings
from app.db.models import Base
from app.db.session import get_engine

config = context.config

# disable_existing_loggers=False keeps the loggers of the program that runs the migration.
if config.config_file_name is not None:
    fileConfig(config.config_file_name, disable_existing_loggers=False)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Print the SQL instead of running it (alembic upgrade head --sql). Needs no connection."""
    url = get_settings().database_url.get_secret_value()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run the migrations on the database of DATABASE_URL."""
    with get_engine().connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
