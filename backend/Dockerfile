# The backend API. The build context is the project root, so the demo invoices can be copied too.

FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.13.5 /uv /usr/local/bin/uv
ENV UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/backend/.venv/bin:$PATH"

# The code looks for the demo invoices in ../demo and keeps the documents in ../data/files, so the
# folders keep the same layout as in the repository.
WORKDIR /app/backend
# The dependencies come first, so changing the code does not install them again.
COPY backend/pyproject.toml backend/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY backend/alembic.ini ./
COPY backend/migrations ./migrations
COPY backend/app ./app
COPY demo /app/demo

RUN useradd --system --no-create-home app \
    && mkdir -p /app/data/files \
    && chown -R app /app/data
USER app

EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=5 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"

# Brings the tables up to date, then serves the API.
CMD ["sh", "-c", "alembic upgrade head && exec fastapi run --host 0.0.0.0 --port 8000"]
