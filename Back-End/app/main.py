import logging
import time
from collections import defaultdict, deque

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import Column, DateTime, Integer, String, inspect, MetaData, Table, text

from app import models
from app.core.database import Base, engine
from app.routers import (
    ai_router,
    notification_router,
    progress_router,
    quiz_router,
    sm2_quiz_router,
    user_router,
    word_router,
)
from app.core.config import settings

app = FastAPI(title="AI VocabGen API")
logger = logging.getLogger(__name__)

IS_PRODUCTION = settings.ENVIRONMENT.lower() == "production"

if IS_PRODUCTION:
    allowed_origins = [
        origin.strip()
        for origin in settings.ALLOWED_ORIGINS.split(",")
        if origin.strip()
    ]
else:
    allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=False if "*" in allowed_origins else True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

_rate_limit_buckets: dict[str, deque[float]] = defaultdict(deque)


@app.middleware("http")
async def security_and_logging_middleware(request: Request, call_next):
    started = time.perf_counter()
    client = request.client.host if request.client else "unknown"
    key = f"{client}:{request.url.path}"
    limits = {
        ("POST", "/login"): (5, 60),
        ("POST", "/auth/forgot-password"): (3, 60),
    }
    limit = limits.get((request.method, request.url.path))
    if limit:
        max_requests, window_seconds = limit
        now = time.time()
        bucket = _rate_limit_buckets[key]
        while bucket and now - bucket[0] > window_seconds:
            bucket.popleft()
        if len(bucket) >= max_requests:
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please try again later."},
            )
        bucket.append(now)

    response = await call_next(request)
    elapsed_ms = (time.perf_counter() - started) * 1000
    logger.info(
        "%s %s -> %s %.1fms",
        request.method,
        request.url.path,
        response.status_code,
        elapsed_ms,
    )
    return response


Base.metadata.create_all(bind=engine)

with engine.begin() as connection:
    inspector = inspect(connection)
    metadata = MetaData()

    def _ensure_column(table_name: str, column: Column):
        existing = {col["name"] for col in inspector.get_columns(table_name)}
        if column.name not in existing:
            col_type = column.type.compile(engine.dialect)
            nullable = "" if column.nullable else " NOT NULL"
            default = ""
            if column.server_default is not None:
                default = f" DEFAULT {column.server_default.arg}"
            connection.execute(
                text(f'ALTER TABLE "{table_name}" ADD COLUMN "{column.name}" {col_type}{default}{nullable}')
            )

    _ensure_column("users", Column("email_verification_code", String(), nullable=True))
    _ensure_column("users", Column("email_verification_attempts", Integer(), server_default=text("0"), nullable=False))
    _ensure_column("users", Column("is_email_verified", Integer(), server_default=text("1"), nullable=False))
    _ensure_column("users", Column("reset_code_expires_at", DateTime(), nullable=True))
    _ensure_column("user_words", Column("is_active", Integer(), default=1, nullable=False))
    _ensure_column("notifications", Column("title", String(), server_default=text("'Notification'"), nullable=False))
    _ensure_column("notifications", Column("type", String(), nullable=True))
    _ensure_column("normal_quiz_items", Column("question_type", String(), nullable=False, default="multiple_choice"))

app.include_router(user_router.router)
app.include_router(word_router.router)
app.include_router(quiz_router.router)
app.include_router(progress_router.router)
app.include_router(notification_router.router)
app.include_router(sm2_quiz_router.router)
app.include_router(ai_router.router)


@app.get("/")
def read_root():
    return {"message": "API is working"}