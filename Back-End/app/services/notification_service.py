
from datetime import datetime, timezone
 
from sqlalchemy.orm import Session
 
from app.models.notification_model import Notification
from app.models.word_model import Word
from app.models.progress_model import Progress
 
 
def _utcnow() -> datetime:
    """Return the current UTC time as a timezone-aware datetime.
 
    Replaces the deprecated ``datetime.utcnow()`` throughout the service.
    SQLAlchemy columns store naive datetimes, so we strip the tzinfo after
    obtaining an aware timestamp — this preserves correctness while keeping
    the DB values timezone-naive (matching the rest of the schema).
    """
    return datetime.now(timezone.utc).replace(tzinfo=None)
 
 
class NotificationService:
    def __init__(self, db: Session, user_id: int) -> None:
        self.db = db
        self.user_id = user_id
 
    def _has_type_today(self, type: str) -> bool:
        today_start = datetime.combine(_utcnow().date(), datetime.min.time())
        return (
            self.db.query(Notification)
            .filter(
                Notification.user_id == self.user_id,
                Notification.type == type,
                Notification.created_at >= today_start,
            )
            .first()
            is not None
        )
 
    def _has_type_ever(self, type: str) -> bool:
        return (
            self.db.query(Notification)
            .filter(
                Notification.user_id == self.user_id,
                Notification.type == type,
            )
            .first()
            is not None
        )
 
    def _create(self, title: str, message: str, type: str) -> Notification:
        notif = Notification(
            user_id=self.user_id,
            title=title,
            message=message,
            type=type,
        )
        self.db.add(notif)
        self.db.flush()
        return notif
 
    def sync_welcome(self) -> Notification | None:
        if not self._has_type_ever("welcome"):
            return self._create(
                "Welcome to AI VocabGen!",
                "Start adding words and complete your first review quiz.",
                "welcome",
            )
        return None
 
    def sync_sm2_due(self) -> Notification | None:
        if self._has_type_today("sm2_due"):
            return None
        now = _utcnow()
        words = (
            self.db.query(Word)
            .filter(
                Word.user_id == self.user_id,
                Word.is_active == 1,
                Word.status != "pending",
            )
            .all()
        )
        due_count = sum(
            1
            for w in words
            if w.next_review_at is None or w.next_review_at <= now
        )
        if due_count > 0:
            return self._create(
                "Your review is ready",
                f"You have {due_count} word{'s' if due_count != 1 else ''} ready for SM2 review.",
                "sm2_due",
            )
        return None
 
    def sync_streak_reminder(self) -> Notification | None:
        if self._has_type_today("streak_reminder"):
            return None
        progress = (
            self.db.query(Progress)
            .filter(Progress.user_id == self.user_id)
            .first()
        )
        if not progress:
            return None
        streak = progress.daily_streak or 0
        if streak <= 0:
            return None
        today = _utcnow().date()
        if progress.last_sm2_quiz_date == today:
            return None
        return self._create(
            "Keep your streak alive",
            "Complete an SM2 Review Quiz today to keep your streak.",
            "streak_reminder",
        )
 
    def sync_hard_words(self) -> Notification | None:
        if self._has_type_today("hard_words"):
            return None
        hard_count = (
            self.db.query(Word)
            .filter(
                Word.user_id == self.user_id,
                Word.is_active == 1,
                Word.status == "hard",
            )
            .count()
        )
        if hard_count > 0:
            return self._create(
                "Practice your hard words",
                f"You have {hard_count} hard word{'s' if hard_count != 1 else ''} that need attention.",
                "hard_words",
            )
        return None
 
    def sync_pending_words(self) -> Notification | None:
        if self._has_type_today("pending_words"):
            return None
        pending_count = (
            self.db.query(Word)
            .filter(
                Word.user_id == self.user_id,
                Word.is_active == 1,
                Word.status == "pending",
            )
            .count()
        )
        if pending_count > 0:
            return self._create(
                "Pending words waiting",
                "Some words are saved for later and will be activated soon.",
                "pending_words",
            )
        return None
 
    def sync_all(self) -> list[Notification]:
        created: list[Notification] = []
        for method in [
            self.sync_welcome,
            self.sync_sm2_due,
            self.sync_streak_reminder,
            self.sync_hard_words,
            self.sync_pending_words,
        ]:
            result = method()
            if result is not None:
                created.append(result)
        if created:
            self.db.commit()
        return created