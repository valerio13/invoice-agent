"""Write the extra invoices as PDF files, to add them by hand from the app in demo mode.

    uv run python -m app.demo.extra /path/to/folder

They are dated relative to today, like the demo set, so add them on the day they are written.
"""

import sys
from datetime import date
from pathlib import Path

from app.demo.catalog import load_extra_invoices
from app.demo.render import render_invoice


def write_extra_invoices(folder: Path, today: date) -> list[Path]:
    """Draw each extra invoice into the folder and return the files written."""
    folder.mkdir(parents=True, exist_ok=True)
    written = []
    for invoice in load_extra_invoices(today):
        path = folder / invoice.file_name
        path.write_bytes(render_invoice(invoice))
        written.append(path)
    return written


def main() -> None:
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    for path in write_extra_invoices(folder, date.today()):
        print(f"Written {path.name} in {path.parent.name}")


if __name__ == "__main__":
    main()
