"""What any source accepts: the file types an invoice comes in and a size limit."""

from pathlib import PurePath

# Media type of each accepted extension, also used to serve the document back.
MEDIA_TYPES = {
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
}
# A larger file is not an invoice, and it would be expensive to send to a model.
MAX_BYTES = 10 * 1024 * 1024


def is_supported(file_name: str) -> bool:
    return PurePath(file_name).suffix.lower() in MEDIA_TYPES


def media_type(file_name: str) -> str:
    return MEDIA_TYPES.get(PurePath(file_name).suffix.lower(), "application/octet-stream")
