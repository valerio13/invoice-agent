"""Interface of an invoice source: where the documents come from."""

from abc import ABC, abstractmethod

from app.domain.models import InvoiceFile


class InvoiceSource(ABC):
    """Gives the invoices waiting to be read. It only reads: nothing is moved or deleted."""

    @abstractmethod
    def fetch(self) -> list[InvoiceFile]:
        """Return the documents the source offers now. The caller skips the ones it already has."""
