# Invoice agent

Reads invoices (PDF and images), extracts supplier, date, number, net amount, VAT, total and currency, and exports them to an Excel workbook. Invoices it is not sure about, totals that do not add up and duplicates are flagged for a human, who reviews them in a desktop app with the document next to its extracted fields.

Status: in progress. Built so far: the settings, the domain models, the database layer, the invoice sources, the demo invoices, a stand-in for the model the services (reading, checks, review, Excel export and metrics) and the REST API, with tests. Still to come: the real model and the desktop app. The rest of the design is the plan and is updated as each part is built.

## Architecture

See [docs/architecture.md](docs/architecture.md).

## Stack

Python 3.12, FastAPI, Pydantic, LangChain, SQLAlchemy 2, Alembic, PostgreSQL, openpyxl and a Flutter desktop app.

## Database

Requires Docker and [uv](https://docs.astral.sh/uv/).

```bash
cp .env.example .env            # then fill in the values
docker compose up -d db         # PostgreSQL on 127.0.0.1:5433
cd backend && uv sync
uv run alembic upgrade head     # create the tables
```

## API

```bash
cd backend && uv run fastapi dev   # http://127.0.0.1:8000, docs at /docs
```

## Backend checks

The tests use an in-memory database and need no `.env`.

```bash
cd backend && uv sync
uv run ruff check . && uv run pytest -q
```

## Demo mode

Runs on fictitious invoices and needs no model key (`DEMO_MODE=true`). With the API running, this replaces every invoice with the demo set:

```bash
curl -X POST http://127.0.0.1:8000/ingest/demo
```

## Security

- No credentials in the repository. Configuration is read from environment variables only.
- An invoice is untrusted input. The model has no tools and its answer is validated before anything is stored.
- The agent only reads invoices and writes the workbook.
- Secrets are scanned with gitleaks on every commit and in CI.

## License

MIT
