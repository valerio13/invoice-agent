"""Interface of the model that reads an invoice."""

from abc import ABC, abstractmethod

from app.domain.models import Extraction, InvoiceFile


class ExtractionError(Exception):
    """The model failed, or answered something that is not a valid extraction."""


class LLMProvider(ABC):
    """Turns one invoice document into validated fields."""

    @abstractmethod
    def extract(self, file: InvoiceFile) -> Extraction:
        """Return the fields of the invoice. Raise ExtractionError if it cannot be read."""
