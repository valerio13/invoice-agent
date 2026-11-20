# Invoice agent

Reads invoices (PDF and images), extracts supplier, date, number, net amount, VAT, total and currency, and exports them to an Excel workbook. Invoices it is not sure about, totals that do not add up and duplicates are flagged for a human, who reviews them in a desktop app with the document next to its extracted fields.

Status: in progress. Built so far: the settings, the domain models, the database layer, the invoice sources, the demo invoices, a stand-in for the model and the real one through OpenRouter, the services (reading, checks, review, Excel export and metrics), the REST API and the desktop app (Overview, Invoices, Review and Export, and adding invoices by dropping them on the window), with tests. The rest of the design is the plan and is updated as each part is built.

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

## Desktop app

Requires Flutter and Xcode. With the API running:

```bash
cd desktop && flutter run -d macos
```

See [desktop/README.md](desktop/README.md).

## Backend checks

The tests use an in-memory database and need no `.env`.

```bash
cd backend && uv sync
uv run ruff check . && uv run pytest -q
```

## Demo mode

Runs on fictitious invoices and needs no model key (`DEMO_MODE=true`). With Docker running and a filled-in `.env`, one command starts the database, creates the tables, starts the API in demo mode on port 8000 (`DEMO_PORT` to change it) and opens the desktop app. An empty database gets the demo invoices; one that has invoices keeps them. Closing the app stops the API:

```bash
scripts/demo.sh
```

With the API already running, this replaces every invoice with the demo set (the "Load demo" button of the Overview screen does the same):

```bash
curl -X POST http://127.0.0.1:8000/ingest/demo
```

To try adding an invoice by hand, this writes a fictitious one that is not in the demo set but that the stand-in model can read. Then drop it on the app or use "Add files" on the Invoices screen, the same day:

```bash
cd backend && uv run python -m app.demo.extra ~/Desktop
```

## Security

- No credentials in the repository. Configuration is read from environment variables only.
- An invoice is untrusted input. The model has no tools and its answer is validated before anything is stored.
- The agent only reads invoices and writes the workbook.
- Secrets are scanned with gitleaks on every commit and in CI.

## Continuous integration

On every push GitHub Actions scans the history for secrets, runs the backend lint and tests, and checks the format, lint and widget tests of the desktop app (`.github/workflows/ci.yml`). The real-app test in `desktop/integration_test/` needs a Mac and is run by hand.

## License

MIT
