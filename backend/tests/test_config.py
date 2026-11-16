import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_settings_come_from_the_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://user:pass@localhost/db")
    monkeypatch.setenv("LLM_PROVIDER", "fake")
    monkeypatch.setenv("LLM_MODEL", "any")
    settings = Settings(_env_file=None)
    assert settings.llm_provider == "fake"
    assert settings.demo_mode is True
    # A secret never shows its value when printed.
    assert "pass" not in repr(settings)


def test_a_missing_required_setting_is_an_error(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("DATABASE_URL", "LLM_PROVIDER", "LLM_MODEL"):
        monkeypatch.delenv(name, raising=False)
    with pytest.raises(ValidationError):
        Settings(_env_file=None)
