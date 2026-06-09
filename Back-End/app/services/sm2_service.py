from dataclasses import dataclass
from datetime import datetime, timedelta
from math import ceil


INITIAL_EASE_FACTOR = 2.5
MIN_EASE_FACTOR = 1.3
MAX_EASE_FACTOR = 2.8
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
    score_delta: int
    next_review_label: str
    error_type: str
    learning_insight: str
    smart_action: str
    achievement_flags: list[str]
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
    delta_by_quality = {
        5: 0.15,
        4: 0.08,
        3: 0.03,
        2: -0.2,
        1: -0.35,
        0: -0.5,
    }
    new_ef = old_ef + delta_by_quality.get(quality, 0)
    return min(MAX_EASE_FACTOR, max(MIN_EASE_FACTOR, round(new_ef, 2)))


def _interval_for_correct_recall(old_interval: int, new_repeats: int, new_ef: float, quality: int) -> int:
    if new_repeats == 1:
        return 2 if quality == 5 else 1
    if new_repeats == 2:
        return 5 if quality == 5 else 3
    if new_repeats == 3:
        return 10 if quality == 5 else 7

    speed_multiplier = {5: 1.25, 4: 1.0, 3: 0.75}.get(quality, 1.0)
    base_interval = max(1, old_interval)
    return ceil(base_interval * new_ef * speed_multiplier)


def _next_review_label(interval_days: int) -> str:
    if interval_days <= 1:
        return "today"
    if interval_days <= 7:
        return "soon"
    return "later"


def _classify_error_type(*, is_correct: bool, quality: int, question_type: str | None, user_answer: str | None) -> str:
    if is_correct:
        return "none"
    if quality == 0 or not (user_answer or "").strip():
        return "memory_failure"
    if quality == 1 and (question_type or "").lower() in {"mcq", "tf", "true_false"}:
        return "confusion_with_similar_words"
    if quality == 1:
        return "misunderstanding"
    return "guessing"


def _learning_insight(*, is_correct: bool, quality: int, new_status: str, wrong_streak: int) -> str:
    if new_status == "mastered":
        return "Strong recall speed and spacing indicate this word is close to permanent memory."
    if is_correct and quality == 5:
        return "Strong recall speed indicates mastery forming."
    if is_correct and quality == 4:
        return "Recall is accurate, with a little more speed still developing."
    if is_correct:
        return "Correct but slow recall suggests this word needs another near-term review."
    if wrong_streak >= 3:
        return "Repeated misses show this word needs focused contextual practice."
    return "The answer was missed, so the word should return quickly for reinforcement."


def _smart_action(*, status: str, wrong_streak: int) -> str:
    if wrong_streak >= 5:
        return "freeze_word"
    if status == "hard" and wrong_streak >= 3:
        return "focus_review"
    if status == "mastered":
        return "boost_interval"
    return "none"


def _achievement_flags(
    *,
    is_correct: bool,
    quality: int,
    old_repeats: int,
    old_status: str,
    new_status: str,
    correct_streak: int,
) -> list[str]:
    flags: list[str] = []
    if is_correct and old_repeats == 0:
        flags.append("first_correct")
    if is_correct and correct_streak >= 5:
        flags.append("5_correct_streak")
    if is_correct and quality == 5:
        flags.append("perfect_answer")
    if old_status != "mastered" and new_status == "mastered":
        flags.append("word_mastered")
    return flags


def apply_modified_sm2(
    word,
    quality: int,
    reviewed_at: datetime | None = None,
    *,
    is_correct: bool | None = None,
    question_type: str | None = None,
    user_answer: str | None = None,
) -> SM2UpdateSnapshot:
    """Apply VocabGen's modified SM2.

    Important design decisions:
    - One wrong answer does not always reset the word to zero.
    - Repeated wrong answers can reset repeats and mark the word as hard.
    - Mastered words are not removed; they are scheduled farther away.
    """
    reviewed_at = reviewed_at or datetime.utcnow()
    quality = max(0, min(5, int(quality)))

    old_score = int(word.score or 0)
    old_repeats = int(word.sm2Repeats or 0)
    old_interval = int(word.sm2IntervalDays or 0)
    old_next = word.nextReviewDate
    old_ef = float(word.sm2EaseFactor or INITIAL_EASE_FACTOR)
    old_status = word.status or "new"
    is_correct = quality >= 3 if is_correct is None else is_correct

    new_ef = _update_ease_factor(old_ef, quality)
    score_delta = {5: 10, 4: 7, 3: 4, 2: -8, 1: -10, 0: -12}.get(quality, 0)
    new_score = max(0, min(100, old_score + score_delta))

    if quality >= 3:
        new_repeats = old_repeats + 1
        word.correctStreak = int(word.correctStreak or 0) + 1
        word.wrongStreak = 0
        new_interval = _interval_for_correct_recall(old_interval, new_repeats, new_ef, quality)
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

    error_type = _classify_error_type(
        is_correct=is_correct,
        quality=quality,
        question_type=question_type,
        user_answer=user_answer,
    )
    learning_insight = _learning_insight(
        is_correct=is_correct,
        quality=quality,
        new_status=word.status,
        wrong_streak=int(word.wrongStreak or 0),
    )
    smart_action = _smart_action(status=word.status, wrong_streak=int(word.wrongStreak or 0))
    achievement_flags = _achievement_flags(
        is_correct=is_correct,
        quality=quality,
        old_repeats=old_repeats,
        old_status=old_status,
        new_status=word.status,
        correct_streak=int(word.correctStreak or 0),
    )

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
        score_delta=score_delta,
        next_review_label=_next_review_label(new_interval),
        error_type=error_type,
        learning_insight=learning_insight,
        smart_action=smart_action,
        achievement_flags=achievement_flags,
        status=word.status,
    )


def is_due(word, now: datetime | None = None) -> bool:
    now = now or datetime.utcnow()
    if not word.nextReviewDate:
        return True
    return word.nextReviewDate <= now
