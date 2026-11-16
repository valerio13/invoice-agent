"""Invoice source that reads the documents of a folder."""

from pathlib import Path

from app.domain.models import InvoiceFile
from app.providers.source.base import InvoiceSource
from app.providers.source.limits import MAX_BYTES, is_supported


class FolderSource(InvoiceSource):
    """Reads the PDF and image files directly inside a folder, in name order."""

    def __init__(self, folder: Path) -> None:
        self._folder = folder

    def fetch(self) -> list[InvoiceFile]:
        if not self._folder.is_dir():
            return []
        files = []
        for path in sorted(self._folder.iterdir()):
            # Links are skipped, so a folder cannot point the reader at files outside it.
            if path.is_symlink() or not path.is_file():
                continue
            if not is_supported(path.name) or path.stat().st_size > MAX_BYTES:
                continue
            files.append(InvoiceFile(file_name=path.name, content=path.read_bytes()))
        return files
