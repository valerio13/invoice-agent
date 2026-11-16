"""The FastAPI application. Run it with `uv run fastapi dev`: it only listens on 127.0.0.1."""

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.api import routes
from app.factory import ConfigurationError

app = FastAPI(
    title="Invoice agent",
    description="Reads invoices, flags the doubtful ones and exports them to Excel.",
    version="0.1.0",
)
for router in (routes.system, routes.invoices, routes.ingest, routes.reports):
    app.include_router(router)


@app.exception_handler(ConfigurationError)
def configuration_error(_: Request, error: ConfigurationError) -> JSONResponse:
    return JSONResponse({"detail": str(error)}, status_code=status.HTTP_503_SERVICE_UNAVAILABLE)
