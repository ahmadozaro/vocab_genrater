import logging
import time
from collections import defaultdict, deque

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

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
    # ✅ في Development نسمح بكل الأصول عشان Flutter يشتغل
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
    columns = {
        row[1]
        for row in connection.exec_driver_sql("PRAGMA table_info(users)").fetchall()
    }
    if "email_verification_code" not in columns:
        connection.exec_driver_sql(
            "ALTER TABLE users ADD COLUMN email_verification_code VARCHAR"
        )
    if "is_email_verified" not in columns:
        connection.exec_driver_sql(
            "ALTER TABLE users ADD COLUMN is_email_verified INTEGER DEFAULT 1 NOT NULL"
        )
    if "reset_code_expires_at" not in columns:
        connection.exec_driver_sql(
            "ALTER TABLE users ADD COLUMN reset_code_expires_at DATETIME"
        )

    word_columns = {
        row[1]
        for row in connection.exec_driver_sql("PRAGMA table_info(user_words)").fetchall()
    }
    if "is_active" not in word_columns:
        connection.exec_driver_sql(
            "ALTER TABLE user_words ADD COLUMN is_active INTEGER DEFAULT 1 NOT NULL"
        )

    notif_columns = {
        row[1]
        for row in connection.exec_driver_sql("PRAGMA table_info(notifications)").fetchall()
    }
    if "title" not in notif_columns:
        connection.exec_driver_sql(
            "ALTER TABLE notifications ADD COLUMN title VARCHAR NOT NULL DEFAULT 'Notification'"
        )
    if "type" not in notif_columns:
        connection.exec_driver_sql(
            "ALTER TABLE notifications ADD COLUMN type VARCHAR"
        )

    q_columns = {
        row[1]
        for row in connection.exec_driver_sql("PRAGMA table_info(normal_quiz_items)").fetchall()
    }
    if "question_type" not in q_columns:
        connection.exec_driver_sql(
            "ALTER TABLE normal_quiz_items ADD COLUMN question_type VARCHAR DEFAULT 'multiple_choice'"
        )

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