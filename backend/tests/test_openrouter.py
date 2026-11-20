"""The real model's provider, tried with a stand-in for the chat model: no key, no network."""

from datetime import date
from decimal import Decimal

import pytest
from langchain_core.messages import BaseMessage
from langchain_core.runnables import RunnableLambda

from app.core.config import Settings
from app.domain.models import InvoiceFile
from app.factory import ConfigurationError, build_llm
from app.providers.llm.base import ExtractionError
from app.providers.llm.openrouter import (
    SYSTEM_PROMPT,
    LangChainLLMProvider,
    ModelAnswer,
    document_block,
)

ANSWER = {
    "is_invoice": True,
    "supplier": "Atlas Software",
    "invoice_number": "AS-0690",
    "issue_date": "2026-11-18",
    "net_amount": 119,
    "vat_rate": 21,
    "vat_amount": 24.99,
    "total": 143.99,
    "currency": "eur",
    "confidence": 0.93,
}


def model_answering(answer: object, sent: list[list[BaseMessage]] | None = None) -> RunnableLambda:
    def invoke(messages: list[BaseMessage]) -> object:
        if sent is not None:
            sent.append(messages)
        if isinstance(answer, Exception):
            raise answer
        return answer

    return RunnableLambda(invoke)


def pdf() -> InvoiceFile:
    return InvoiceFile(file_name="atlas.pdf", content=b"%PDF-1.4 fictitious")


def test_the_pdf_goes_as_a_file_part_and_the_answer_becomes_an_extraction() -> None:
    sent: list[list[BaseMessage]] = []
    extraction = LangChainLLMProvider(model_answering(ANSWER, sent)).extract(pdf())

    system, human = sent[0]
    assert system.content == SYSTEM_PROMPT
    block = human.content[1]
    assert block["type"] == "file"
    assert block["mime_type"] == "application/pdf"
    assert block["filename"] == "atlas.pdf"

    assert extraction.supplier == "Atlas Software"
    assert extraction.issue_date == date(2026, 11, 18)
    assert extraction.net_amount == Decimal("119.00")
    assert extraction.total == Decimal("143.99")
    assert extraction.currency == "EUR"
    assert extraction.amounts_add_up()


def test_an_image_goes_as_an_image_part() -> None:
    block = document_block(InvoiceFile(file_name="scan.JPG", content=b"\xff\xd8"))
    assert block == {"type": "image", "base64": "/9g=", "mime_type": "image/jpeg"}


def test_amounts_are_rounded_to_cents_and_a_wrong_total_is_kept() -> None:
    answer = ANSWER | {"vat_amount": 24.989, "total": 150}
    extraction = LangChainLLMProvider(model_answering(answer)).extract(pdf())
    assert extraction.vat_amount == Decimal("24.99")
    # The model copies what is printed; the checks flag it later.
    assert not extraction.amounts_add_up()


def test_a_model_answer_object_is_accepted_too() -> None:
    answer = ModelAnswer.model_validate(ANSWER)
    assert LangChainLLMProvider(model_answering(answer)).extract(pdf()).invoice_number == "AS-0690"


@pytest.mark.parametrize(
    ("answer", "reason"),
    [
        (ANSWER | {"is_invoice": False}, "does not look like an invoice"),
        (ANSWER | {"currency": "euro"}, "not valid"),
        (ANSWER | {"issue_date": "yesterday"}, "not valid"),
        (ANSWER | {"total": -5}, "not valid"),
        (TimeoutError("timed out"), "could not read"),
    ],
)
def test_what_cannot_be_stored_is_an_extraction_error(answer: object, reason: str) -> None:
    with pytest.raises(ExtractionError, match=reason):
        LangChainLLMProvider(model_answering(answer)).extract(pdf())


def test_a_file_that_is_not_a_pdf_or_an_image_is_not_sent() -> None:
    sent: list[list[BaseMessage]] = []
    with pytest.raises(ExtractionError, match="not a PDF"):
        LangChainLLMProvider(model_answering(ANSWER, sent)).extract(
            InvoiceFile(file_name="notes.txt", content=b"hello")
        )
    assert sent == []


def settings(**changes: object) -> Settings:
    fields: dict[str, object] = {
        "database_url": "sqlite://",
        "llm_provider": "openrouter",
        "llm_model": "anthropic/claude-haiku-5.5",
        "openrouter_api_key": "sk-test-not-a-real-key",
    }
    return Settings(_env_file=None, **(fields | changes))


def test_the_factory_builds_the_real_model_only_with_a_key() -> None:
    assert isinstance(build_llm(settings()), LangChainLLMProvider)
    with pytest.raises(ConfigurationError, match="OPENROUTER_API_KEY"):
        build_llm(settings(openrouter_api_key=""))
    with pytest.raises(ConfigurationError, match="LLM_MODEL"):
        build_llm(settings(llm_model=""))
