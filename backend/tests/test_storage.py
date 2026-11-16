from app.domain.models import InvoiceFile
from app.providers.source.upload import UploadSource
from app.providers.storage import FileStore


def test_the_store_keeps_documents_by_hash(files: FileStore) -> None:
    document = InvoiceFile(file_name="a.pdf", content=b"%PDF-1")
    files.save(document)
    files.save(InvoiceFile(file_name="b.pdf", content=b"%PDF-1"))

    assert files.load(document.file_hash) == b"%PDF-1"
    assert files.load("0" * 64) is None


def test_the_store_refuses_anything_that_is_not_a_hash(files: FileStore) -> None:
    assert files.load("../../.env") is None
    assert files.load("A" * 64) is None


def test_uploads_keep_only_invoices_and_strip_paths() -> None:
    source = UploadSource(
        [
            ("../../etc/invoice.pdf", b"1"),
            ("C:\\Users\\scan.JPG", b"2"),
            ("notes.txt", b"3"),
            ("empty.pdf", b""),
            ("big.pdf", b"0" * (10 * 1024 * 1024 + 1)),
        ]
    )
    assert [file.file_name for file in source.fetch()] == ["invoice.pdf", "scan.JPG"]
    assert source.rejected == ["notes.txt", "empty.pdf", "big.pdf"]
