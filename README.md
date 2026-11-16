# Invoice agent

Reads invoices (PDF and images), extracts supplier, date, number, net amount, VAT, total and currency, and exports them to an Excel workbook. Invoices it is not sure about, totals that do not add up and duplicates are flagged for a human, who reviews them in a desktop app with the document next to its extracted fields.

Status: in progress. Built so far: the settings and the domain models of the backend, with tests. The rest of the design is the plan and is updated as each part is built.

## Architecture

See [docs/architecture.md](docs/architecture.md).

## Stack

Python 3.12, FastAPI, Pydantic, LangChain, SQLAlchemy 2, Alembic, PostgreSQL, openpyxl and a Flutter desktop app.

## Backend checks

Requires [uv](https://docs.astral.sh/uv/).

```bash
cd backend && uv sync
uv run ruff check . && uv run pytest -q
```

## Demo mode

Runs on fictitious invoices and needs no model key (`DEMO_MODE=true`).

## Security

- No credentials in the repository. Configuration is read from environment variables only.
- An invoice is untrusted input. The model has no tools and its answer is validated before anything is stored.
- The agent only reads invoices and writes the workbook.
- Secrets are scanned with gitleaks on every commit and in CI.

## License

MIT
