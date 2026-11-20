"""Stand-in for the model, for demo mode and tests: no key, no network, no cost."""

from collections.abc import Callable
from datetime import date

from app.demo.catalog import load_demo_invoices, load_extra_invoices
from app.domain.models import Extraction, InvoiceFile
from app.providers.llm.base import ExtractionError, LLMProvider


class FakeLLMProvider(LLMProvider):
    """Knows what each demo invoice says, and the extra ones, by file name. Nothing else."""

    def __init__(self, today: Callable[[], date] = date.today) -> None:
        self._today = today

    def extract(self, file: InvoiceFile) -> Extraction:
        today = self._today()
        for invoice in load_demo_invoices(today) + load_extra_invoices(today):
            if invoice.file_name == file.file_name:
                return invoice.expected_extraction()
        raise ExtractionError(f"The fake model only knows the demo invoices, not {file.file_name}.")
