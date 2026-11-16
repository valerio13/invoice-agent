"""Invoice source for files dropped on the app and sent to the API."""

from pathlib import PurePath

from app.domain.models import InvoiceFile
from app.providers.source.base import InvoiceSource
from app.providers.source.limits import MAX_BYTES, is_supported


class UploadSource(InvoiceSource):
    """Offers the uploaded files that look like invoices. The rest are listed in `rejected`."""

    def __init__(self, uploads: list[tuple[str, bytes]]) -> None:
        self._files: list[InvoiceFile] = []
        self.rejected: list[str] = []
        for raw_name, content in uploads:
            # Only the last part of the name is kept: a name cannot carry a path.
            name = PurePath(raw_name.replace("\\", "/")).name
            if name and is_supported(name) and 0 < len(content) <= MAX_BYTES:
                self._files.append(InvoiceFile(file_name=name, content=content))
            else:
                self.rejected.append(name or raw_name)

    def fetch(self) -> list[InvoiceFile]:
        return list(self._files)
