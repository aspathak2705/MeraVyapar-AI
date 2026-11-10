from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.logging import setup_logging, logger
from app.core.middleware import RequestCorrelationMiddleware
from app.core.exceptions import BaseAPIException
from app.gateway.router import gateway_api_router

setup_logging()


@asynccontextmanager
async def gateway_lifespan(app: FastAPI):
    """
    Stateless lifespan for Google Cloud Run deployment.
    Does NOT connect to PostgreSQL, perform migrations, or establish DB connection pools.
    """
    logger.info("MeraVyapar AI Stateless Cloud Gateway initialized (PostgreSQL decoupled)")
    yield
    logger.info("MeraVyapar AI Stateless Cloud Gateway shutdown cleanly")


app = FastAPI(
    title=f"{settings.PROJECT_NAME} — Stateless Gateway",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=gateway_lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Request correlation middleware
app.add_middleware(RequestCorrelationMiddleware)


@app.exception_handler(BaseAPIException)
async def base_api_exception_handler(request: Request, exc: BaseAPIException):
    request_id = getattr(request.state, "request_id", "N/A")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "message": exc.message,
            "error": {
                "code": exc.error_code,
                "details": exc.details,
                "request_id": request_id,
            }
        },
        headers={"X-Request-ID": request_id}
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", "N/A")
    logger.error("Unhandled exception in gateway: %s", str(exc), exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "message": "Internal Server Error",
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "request_id": request_id,
            }
        },
        headers={"X-Request-ID": request_id}
    )


# Mount strictly stateless gateway routes
app.include_router(gateway_api_router, prefix=settings.API_V1_STR)
