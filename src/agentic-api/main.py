import contextlib
import logging

import fastapi
import telemetry


@contextlib.asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    telemetry.configure_opentelemetry()
    yield


app = fastapi.FastAPI(lifespan=lifespan)
logger = logging.getLogger(__name__)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "healthy", "message": "Agentic API is running"}


@app.get("/health")
async def health():
    """Health check endpoint for container orchestration."""
    return {"status": "healthy"}