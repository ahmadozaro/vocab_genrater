import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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


app = FastAPI(title="AI VocabGen API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

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
