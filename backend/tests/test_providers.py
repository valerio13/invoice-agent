from pathlib import Path

import pytest

from app.domain.models import InvoiceFile
from app.providers.llm.base import ExtractionError
from app.providers.llm.fake import FakeLLMProvider
from app.providers.source.base import InvoiceSource
from app.providers.source.folder import MAX_BYTES, FolderSource


def test_a_source_can_only_read() -> None:
    """The agent never moves, deletes, pays or sends anything."""
    public = {name for name in vars(InvoiceSource) if not name.startswith("_")}
    assert public == {"fetch"}


def test_the_folder_source_reads_invoices_in_name_order(tmp_path: Path) -> None:
    (tmp_path / "b.pdf").write_bytes(b"%PDF b")
    (tmp_path / "a.PNG").write_bytes(b"png")
    files = FolderSource(tmp_path).fetch()
    assert [file.file_name for file in files] == ["a.PNG", "b.pdf"]
    assert files[1].content == b"%PDF b"


def test_the_folder_source_skips_what_is_not_an_invoice(tmp_path: Path) -> None:
    (tmp_path / "notes.txt").write_text("hello")
    (tmp_path / "huge.pdf").write_bytes(b"0" * (MAX_BYTES + 1))
    (tmp_path / "folder.pdf").mkdir()
    outside = tmp_path.parent / "outside.pdf"
    outside.write_bytes(b"%PDF secret")
    (tmp_path / "link.pdf").symlink_to(outside)
    assert FolderSource(tmp_path).fetch() == []


def test_a_missing_folder_gives_nothing(tmp_path: Path) -> None:
    assert FolderSource(tmp_path / "nowhere").fetch() == []


def test_the_same_content_has_the_same_hash() -> None:
    first = InvoiceFile(file_name="a.pdf", content=b"same")
    second = InvoiceFile(file_name="b.pdf", content=b"same")
    assert first.file_hash == second.file_hash
    assert len(first.file_hash) == 64
    assert "same" not in repr(first)


def test_the_fake_model_refuses_an_unknown_document() -> None:
    with pytest.raises(ExtractionError):
        FakeLLMProvider().extract(InvoiceFile(file_name="unknown.pdf", content=b"%PDF"))
