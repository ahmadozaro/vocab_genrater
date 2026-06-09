
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
 
from app.auth import get_current_user
from app.core.database import get_db
from app.models.notification_model import Notification
from app.models.user_model import User
from app.models.word_model import Word
from app.schemas.progress_schema import ProgressResponse, ProgressUpdate
from app.utils.quiz_helpers import get_or_create_progress
 
 
router = APIRouter()
 
 
def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)
 
 
def _progress_response(db: Session, progress, notifications_count: int = 0) -> dict:
    user_id = progress.user_id
    now = _utcnow()
    base = db.query(Word).filter(Word.user_id == user_id, Word.is_active == 1)
    mastered_words = base.filter(Word.status == "mastered").count()
    new_words = base.filter(Word.status.in_(["new", "learning"])).count()
    active_words = base.filter(Word.status != "pending").count()
    due_review_count = (
        base
        .filter(
            Word.status != "pending",
            (Word.next_review_at == None) | (Word.next_review_at <= now),
        )
        .count()
    )
    return {
        "id": progress.id,
        "userId": user_id,
        "dailyStreak": progress.daily_streak or 0,
        "masteredWords": mastered_words,
        "newWords": new_words,
        "activeWordsCount": active_words,
        "dueReviewCount": due_review_count,
        "completedDailyQuizzes": progress.completed_sm2_quizzes or 0,
        "completedSm2Quizzes": progress.completed_sm2_quizzes or 0,
        "lastSm2QuizDate": progress.last_sm2_quiz_date,
        "notifications": notifications_count,
        "created_at": progress.updated_at,
    }
 
 
@router.get("/progress/me", response_model=ProgressResponse)
def get_my_progress(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    progress = get_or_create_progress(db, current_user.id)
    db.commit()
    notifications_count = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
        .count()
    )
    return _progress_response(db, progress, notifications_count)
 
 
@router.post("/progress/update", response_model=ProgressResponse)
def update_progress(
    data: ProgressUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    progress = get_or_create_progress(db, current_user.id)
 
    if data.dailyStreak is not None:
        progress.daily_streak = data.dailyStreak
    if data.completedDailyQuizzes is not None:
        progress.completed_sm2_quizzes = data.completedDailyQuizzes
    if data.completedSm2Quizzes is not None:
        progress.completed_sm2_quizzes = data.completedSm2Quizzes
 
    db.commit()
    db.refresh(progress)
    notifications_count = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
        .count()
    )
    return _progress_response(db, progress, notifications_count)