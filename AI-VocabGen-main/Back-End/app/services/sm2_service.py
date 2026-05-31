from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from math import ceil


INITIAL_EASE_FACTOR = 2.5
MIN_EASE_FACTOR = 1.3
MAX_INTERVAL_DAYS = 60
MASTERED_SCORE = 85
MASTERED_REPEATS = 4
MASTERED_INTERVAL_DAYS = 21


@dataclass
class SM2UpdateSnapshot:
    old_score: int
    new_score: int
    old_repeats: int
    new_repeats: int
    old_interval_days: int
    new_interval_days: int
    old_ease_factor: float
    new_ease_factor: float
    old_next_review_at: datetime | None
    new_next_review_at: datetime
    quality: int
    status: str


def normalize_answer(value: str | None) -> str:
    return " ".join((value or "").strip().lower().split())


def infer_quality(*, is_correct: bool, duration_seconds: int | None, skipped: bool = False) -> int:
    """Infer SM2 quality from correctness and response time.

    This avoids asking the user whether the question was difficult.
    """
    if skipped or duration_seconds is None and not is_correct:
        return 0 if skipped else 1
    if not is_correct:
        return 1
    duration = duration_seconds or 0
    if duration > 20:
        return 3
    if duration > 8:
        return 4
    return 5


def _update_ease_factor(old_ef: float, quality: int) -> float:
    new_ef = old_ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    return max(MIN_EASE_FACTOR, round(new_ef, 2))


def apply_modified_sm2(word, quality: int, reviewed_at: datetime | None = None) -> SM2UpdateSnapshot:
    """Apply VocabGen's modified SM2.

    Important design decisions:
    - One wrong answer does not always reset the word to zero.
    - Repeated wrong answers can reset repeats and mark the word as hard.
    - Mastered words are not removed; they are scheduled farther away.
    """
    reviewed_at = reviewed_at or datetime.now(timezone.utc).replace(tzinfo=None)
    quality = max(0, min(5, int(quality)))

    old_score = int(word.score or 0)
    old_repeats = int(word.sm2Repeats or 0)
    old_interval = int(word.sm2IntervalDays or 0)
    old_next = word.nextReviewDate
    old_ef = float(word.sm2EaseFactor or INITIAL_EASE_FACTOR)

    new_ef = _update_ease_factor(old_ef, quality)
    score_delta = {5: 10, 4: 7, 3: 4, 2: -5, 1: -8, 0: -12}.get(quality, 0)
    new_score = max(0, min(100, old_score + score_delta))

    if quality >= 3:
        new_repeats = old_repeats + 1
        word.correctStreak = int(word.correctStreak or 0) + 1
        word.wrongStreak = 0

        if new_repeats == 1:
            new_interval = 1
        elif new_repeats == 2:
            new_interval = 3
        elif new_repeats == 3:
            new_interval = 7
        else:
            base_interval = max(1, old_interval)
            new_interval = ceil(base_interval * new_ef)
    else:
        word.correctStreak = 0
        word.wrongStreak = int(word.wrongStreak or 0) + 1
        if word.wrongStreak >= 3 or quality == 0:
            new_repeats = 0
        elif word.wrongStreak >= 2:
            new_repeats = max(0, old_repeats - 2)
        else:
            new_repeats = max(0, old_repeats - 1)
        new_interval = 1

    new_interval = min(MAX_INTERVAL_DAYS, max(1, new_interval))
    new_next = reviewed_at + timedelta(days=new_interval)

    word.sm2EaseFactor = new_ef
    word.sm2Repeats = new_repeats
    word.sm2IntervalDays = new_interval
    word.nextReviewDate = new_next
    word.lastReviewedAt = reviewed_at
    word.score = new_score

    if new_score >= MASTERED_SCORE and new_repeats >= MASTERED_REPEATS and new_interval >= MASTERED_INTERVAL_DAYS:
        word.status = "mastered"
    elif int(word.wrongStreak or 0) >= 3:
        word.status = "hard"
    elif new_repeats == 0:
        word.status = "learning" if quality < 3 else "new"
    elif new_repeats <= 2:
        word.status = "learning"
    else:
        word.status = "review"

    return SM2UpdateSnapshot(
        old_score=old_score,
        new_score=new_score,
        old_repeats=old_repeats,
        new_repeats=new_repeats,
        old_interval_days=old_interval,
        new_interval_days=new_interval,
        old_ease_factor=old_ef,
        new_ease_factor=new_ef,
        old_next_review_at=old_next,
        new_next_review_at=new_next,
        quality=quality,
        status=word.status,
    )


def is_due(word, now: datetime | None = None) -> bool:
    now = now or datetime.utcnow()
    if not word.nextReviewDate:
        return True
    return word.nextReviewDate <= now
