"""Keeps a copy of each document, named by its SHA-256, so the review screen can show it."""

import re
from pathlib import Path

from app.domain.models import InvoiceFile

# A file hash is 64 hex characters. Anything else is refused, so a name cannot leave the folder.
HASH = re.compile(r"^[0-9a-f]{64}$")


class FileStore:
    """A folder of documents. The same bytes are written once, however many names they had."""

    def __init__(self, root: Path) -> None:
        self._root = root

    def save(self, file: InvoiceFile) -> None:
        path = self._root / file.file_hash
        if not path.exists():
            self._root.mkdir(parents=True, exist_ok=True)
            path.write_bytes(file.content)

    def load(self, file_hash: str) -> bytes | None:
        """Return the document with this hash, or None if it is not kept."""
        if not HASH.match(file_hash):
            return None
        path = self._root / file_hash
        return path.read_bytes() if path.is_file() else None
