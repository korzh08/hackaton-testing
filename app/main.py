import asyncio
import os
import socket
import sys
import time

from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from pydantic import BaseModel

APP_VERSION = os.getenv("APP_VERSION", "v1.0.0")
APP_ENV = os.getenv("APP_ENV", "production")
API_TOKEN = os.getenv("API_TOKEN", "default-insecure-secret-token")
API_TOKEN_PREVIOUS = os.getenv("API_TOKEN_PREVIOUS", "")
FAULT_MODE = os.getenv("FAULT_MODE", "normal")  # normal | error500 | latency | crash
FAULT_ERROR_RATE = float(os.getenv("FAULT_ERROR_RATE", "0.0"))

app = FastAPI(
    title="Cloud DevOps Demo Microservice",
    description="Demo REST API for MTS Cloud DevOps Pipeline Case",
    version=APP_VERSION,
)

# Prometheus Metrics
REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests handled by the service",
    ["method", "endpoint", "status"],
)
REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)
APP_INFO = Gauge(
    "demo_api_info",
    "Application metadata information",
    ["version", "environment", "hostname"],
)
APP_INFO.labels(
    version=APP_VERSION, environment=APP_ENV, hostname=socket.gethostname()
).set(1)

# In-memory item store for demonstration
ITEMS_DB: list[dict[str, str]] = [
    {"id": "1", "name": "Kubernetes Cluster Node", "category": "infra"},
    {"id": "2", "name": "Ingress NGINX Controller", "category": "network"},
    {"id": "3", "name": "Prometheus Monitoring Pod", "category": "observability"},
]

security = HTTPBearer(auto_error=False)


class ItemCreate(BaseModel):
    name: str
    category: str | None = "general"


def verify_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),  # noqa: B008
) -> str:
    """Verifies Bearer token supporting zero-downtime secret rotation (both current & previous tokens accepted)."""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = credentials.credentials
    # Dual-token verification for zero-downtime rotation
    if token == API_TOKEN:
        return "current"
    if API_TOKEN_PREVIOUS and token == API_TOKEN_PREVIOUS:
        return "previous"
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid authorization token",
        headers={"WWW-Authenticate": "Bearer"},
    )


@app.middleware("http")
async def prometheus_and_fault_middleware(request: Request, call_next):
    start_time = time.time()
    path = request.url.path

    # Fault injection: latency simulation
    if FAULT_MODE == "latency" and path.startswith("/api/"):
        await asyncio.sleep(0.6)  # Exceeds standard 500ms SLA for canary testing

    # Fault injection: 500 error simulation for canary auto-rollback demonstration
    if FAULT_MODE == "error500" and path.startswith("/api/v1/items"):
        import random
        threshold = FAULT_ERROR_RATE if FAULT_ERROR_RATE > 0 else 0.5
        if random.random() < threshold:
            REQUESTS_TOTAL.labels(
                method=request.method, endpoint=path, status="500"
            ).inc()
            REQUEST_DURATION.labels(method=request.method, endpoint=path).observe(
                time.time() - start_time
            )
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={"error": "InjectedFaultError", "message": "Simulated canary fault"},
            )

    try:
        response = await call_next(request)
        status_code = str(response.status_code)
    except Exception:
        status_code = "500"
        REQUESTS_TOTAL.labels(
            method=request.method, endpoint=path, status=status_code
        ).inc()
        REQUEST_DURATION.labels(method=request.method, endpoint=path).observe(
            time.time() - start_time
        )
        raise

    duration = time.time() - start_time
    # Normalize endpoints for Prometheus metrics
    metric_endpoint = path
    if path.startswith("/api/v1/items/"):
        metric_endpoint = "/api/v1/items/{id}"

    REQUESTS_TOTAL.labels(
        method=request.method, endpoint=metric_endpoint, status=status_code
    ).inc()
    REQUEST_DURATION.labels(
        method=request.method, endpoint=metric_endpoint
    ).observe(duration)
    return response


@app.get("/healthz", tags=["Health"])
def healthz():
    """Liveness probe: verifies that the process is alive."""
    if FAULT_MODE == "crash":
        raise HTTPException(status_code=500, detail="Crashing due to fault mode")
    return {"status": "ok", "timestamp": time.time()}


@app.get("/readyz", tags=["Health"])
def readyz():
    """Readiness probe: verifies that the app is ready to serve traffic."""
    return {"status": "ready", "version": APP_VERSION}


@app.get("/metrics", tags=["Observability"])
def metrics():
    """Prometheus metrics endpoint."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/v1/info", tags=["General"])
def get_info():
    """Returns application metadata, version and host info."""
    return {
        "version": APP_VERSION,
        "environment": APP_ENV,
        "hostname": socket.gethostname(),
        "fault_mode": FAULT_MODE,
        "fault_error_rate": FAULT_ERROR_RATE,
        "dual_token_active": bool(API_TOKEN_PREVIOUS),
    }


@app.get("/api/v1/items", tags=["Items"])
def get_items(auth_status: str = Depends(verify_token)):
    """Lists items (Protected with Bearer token)."""
    return {
        "items": ITEMS_DB,
        "count": len(ITEMS_DB),
        "auth_token_type": auth_status,
        "served_by": socket.gethostname(),
        "version": APP_VERSION,
    }


@app.post("/api/v1/items", tags=["Items"], status_code=status.HTTP_201_CREATED)
def create_item(item: ItemCreate, auth_status: str = Depends(verify_token)):
    """Creates a new item (Protected with Bearer token)."""
    new_id = str(len(ITEMS_DB) + 1)
    new_item = {"id": new_id, "name": item.name, "category": item.category or "general"}
    ITEMS_DB.append(new_item)
    return {"created": new_item, "auth_token_type": auth_status}


@app.post("/api/v1/fault", tags=["Testing"])
def inject_fault(mode: str = "normal", error_rate: float = 0.5):
    """Dynamically configure fault injection for testing Canary rollback and AIOps."""
    global FAULT_MODE, FAULT_ERROR_RATE
    FAULT_MODE = mode
    FAULT_ERROR_RATE = error_rate
    if mode == "crash":
        # Simulates fatal crash loop for SRE RCA diagnostics
        sys.exit(1)
    return {"fault_mode": FAULT_MODE, "fault_error_rate": FAULT_ERROR_RATE}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
