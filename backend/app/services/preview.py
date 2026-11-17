"""Preview: the first page of a document as an image, for the review screen.

The desktop app shows images only, so a PDF is drawn here with PDFium (pypdfium2).
"""

from io import BytesIO

import pypdfium2 as pdfium

from app.providers.source.limits import media_type

# Width of the drawn page in pixels: sharp at twice the size it is shown in the app.
PREVIEW_WIDTH = 1200


class PreviewError(Exception):
    """The document cannot be drawn."""


def render_preview(content: bytes, file_name: str) -> tuple[bytes, str]:
    """Return the first page as image bytes and their media type. Images come back as they are."""
    kind = media_type(file_name)
    if kind != "application/pdf":
        return content, kind
    try:
        document = pdfium.PdfDocument(content)
        try:
            page = document[0]
            scale = PREVIEW_WIDTH / page.get_width()
            image = page.render(scale=scale).to_pil()
        finally:
            document.close()
    except (pdfium.PdfiumError, IndexError) as error:
        raise PreviewError("The document cannot be drawn.") from error
    buffer = BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue(), "image/png"
