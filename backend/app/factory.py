"""The one place that reads the settings and chooses the implementation of each interface."""

from pathlib import Path

from app.core.config import Settings
from app.providers.llm.base import LLMProvider
from app.providers.llm.fake import FakeLLMProvider
from app.providers.source.folder import FolderSource
from app.providers.storage import FileStore


class ConfigurationError(Exception):
    """The settings ask for something that is missing or not available."""


def build_llm(settings: Settings) -> LLMProvider:
    if settings.llm_provider == "fake":
        return FakeLLMProvider()
    if settings.llm_provider == "openrouter":
        raise ConfigurationError(
            "The OpenRouter model is not available yet. Use LLM_PROVIDER=fake."
        )
    raise ConfigurationError(
        f"Unknown LLM_PROVIDER {settings.llm_provider!r}: use fake or openrouter."
    )


def build_file_store(settings: Settings) -> FileStore:
    return FileStore(settings.files_dir)


def build_folder_source(settings: Settings) -> FolderSource:
    if not settings.invoice_folder:
        raise ConfigurationError("Set INVOICE_FOLDER in .env to read invoices from a folder.")
    folder = Path(settings.invoice_folder).expanduser()
    if not folder.is_dir():
        raise ConfigurationError("INVOICE_FOLDER is not a folder.")
    return FolderSource(folder)
