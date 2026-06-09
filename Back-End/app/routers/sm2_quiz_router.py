
import json
import random
from datetime import date, datetime, timedelta, timezone
 
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
 
from app.auth import get_current_user
from app.core.database import get_db
from app.models.progress_model import Progress
from app.models.sm2_quiz_model import SM2Quiz, SM2QuizItem
from app.models.user_model import User
from app.models.word_model import Word
from app.schemas.sm2_schema import (
    SM2DueResponse,
    SM2ItemResult,
    SM2QuestionResponse,
    SM2StartResponse,
    SM2SubmitRequest,
    SM2SubmitResponse,
)
from app.services.sm2_service import apply_modified_sm2, infer_quality
from app.utils.quiz_helpers import (
    normalize_answer,
    get_or_create_progress,
    generate_mcq,
    generate_fill_in_blank,
    generate_true_false,
    QUESTION_TYPES,
)
 
 
router = APIRouter(prefix="/sm2", tags=["SM2 Review Quiz"])
MIN_SM2_QUESTIONS = 5
MAX_SM2_QUESTIONS = 15
 
 
def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)
 
 
# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
 
def _is_due(word: Word, now: datetime | None = None) -> bool:
    now = now or _utcnow()
    return (
        bool(word.is_active)
        and word.status != "pending"
        and (word.next_review_at is None or word.next_review_at <= now)
    )
 
 
def _overdue_days(word: Word, now: datetime | None = None) -> int:
    now = now or _utcnow()
    if not word.next_review_at or word.next_review_at > now:
        return 0
    return max(0, (now.date() - word.next_review_at.date()).days)
 
 
def _select_sm2_words(words: list[Word], limit: int = MAX_SM2_QUESTIONS) -> list[Word]:
    now = _utcnow()
    active_words = [w for w in words if w.is_active == 1 and w.status != "pending"]
    selected: list[Word] = []
    seen: set[int] = set()
 
    groups = [
        sorted(
            [w for w in active_words if _is_due(w, now)],
            key=lambda w: (-_overdue_days(w, now), w.score or 0),
        ),
        sorted([w for w in active_words if w.status == "hard"], key=lambda w: w.score or 0),
        sorted([w for w in active_words if (w.score or 0) < 60], key=lambda w: w.score or 0),
        sorted(
            [w for w in active_words if w.status in ("new", "learning")],
            key=lambda w: w.id,
        ),
        sorted(active_words, key=lambda w: w.id, reverse=True),
    ]
 
    cap = min(limit, len(active_words))
    for group in groups:
        for word in group:
            if word.id in seen:
                continue
            selected.append(word)
            seen.add(word.id)
            if len(selected) >= cap:
                return selected
    return selected
 
 
def _item_response(item: SM2QuizItem) -> SM2QuestionResponse:
    try:
        options = json.loads(item.options or "[]")
    except json.JSONDecodeError:
        options = []
    return SM2QuestionResponse(
        itemId=item.id,
        userWordId=item.userWordId,
        questionText=item.questionText,
        questionType=item.questionType,
        options=options,
    )
 
 
def _update_streak(
    db: Session, user_id: int, has_real_answer: bool
) -> tuple[bool, int]:
    progress = get_or_create_progress(db, user_id)
    today = date.today()
 
    if not has_real_answer:
        return False, progress.daily_streak or 0
 
    if progress.last_sm2_quiz_date == today:
        progress.completed_sm2_quizzes = (progress.completed_sm2_quizzes or 0) + 1
        return False, progress.daily_streak or 0
 
    if progress.last_sm2_quiz_date == today - timedelta(days=1):
        progress.daily_streak = (progress.daily_streak or 0) + 1
    else:
        progress.daily_streak = 1
 
    progress.last_sm2_quiz_date = today
    progress.completed_sm2_quizzes = (progress.completed_sm2_quizzes or 0) + 1
    return True, progress.daily_streak
 
 
# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
 
@router.get("/due-summary", response_model=SM2DueResponse)
def get_sm2_due_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = _utcnow()
    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.is_active == 1)
        .all()
    )
    due_count = sum(1 for w in words if _is_due(w, now))
    overdue_count = sum(1 for w in words if _overdue_days(w, now) > 0)
    hard_count = sum(1 for w in words if w.status == "hard")
    pending_count = sum(1 for w in words if w.status == "pending")
    future_reviews = [
        w.next_review_at
        for w in words
        if w.status != "pending" and w.next_review_at and w.next_review_at > now
    ]
    return SM2DueResponse(
        dueCount=due_count,
        overdueCount=overdue_count,
        hardCount=hard_count,
        pendingCount=pending_count,
        nextReviewAt=min(future_reviews) if future_reviews else None,
    )
 
 
# Legacy alias
@router.get("/due", response_model=SM2DueResponse)
def get_sm2_due_summary_legacy(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_sm2_due_summary(db=db, current_user=current_user)
 
 
@router.post("/quizzes/start", response_model=SM2StartResponse)
def start_sm2_quiz(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.is_active == 1)
        .all()
    )
    selected_words = _select_sm2_words(words)
    if not selected_words:
        raise HTTPException(
            status_code=400,
            detail="No active words available for SM2 review",
        )
 
    target_count = min(MAX_SM2_QUESTIONS, max(MIN_SM2_QUESTIONS, len(selected_words)))
    selected_words = selected_words[:target_count]
 
    quiz = SM2Quiz(
        userId=current_user.id,
        status="in_progress",
        questionsCount=len(selected_words),
        score=0,
    )
    db.add(quiz)
    db.flush()
 
    all_texts = [w.text for w in words if w.text]
    created_items: list[SM2QuizItem] = []
 
    for i, word in enumerate(selected_words):
        r = i % len(QUESTION_TYPES)
        if r == 1:
            question_text, opts, correct = generate_fill_in_blank(word)
            qtype = "fill"
        elif r == 2:
            question_text, opts, correct = generate_true_false(word, all_texts)
            qtype = "tf"
        else:
            question_text, opts, correct = generate_mcq(word, words)
            qtype = "mcq"
 
        item = SM2QuizItem(
            quizId=quiz.id,
            userWordId=word.id,
            questionText=question_text,
            questionType=qtype,
            correctAnswer=correct,
            options=json.dumps(opts, ensure_ascii=False),
        )
        db.add(item)
        created_items.append(item)
 
    db.commit()
    db.refresh(quiz)
    for item in created_items:
        db.refresh(item)
 
    return SM2StartResponse(
        quizId=quiz.id,
        questions=[_item_response(item) for item in created_items],
    )
 
 
@router.post("/quizzes/{quiz_id}/submit", response_model=SM2SubmitResponse)
def submit_sm2_quiz(
    quiz_id: int,
    data: SM2SubmitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = (
        db.query(SM2Quiz)
        .filter(SM2Quiz.id == quiz_id, SM2Quiz.userId == current_user.id)
        .first()
    )
    if not quiz:
        raise HTTPException(status_code=404, detail="SM2 quiz not found")
    if quiz.status != "in_progress":
        raise HTTPException(
            status_code=400,
            detail="This SM2 quiz was already submitted or abandoned",
        )
 
    items = db.query(SM2QuizItem).filter(SM2QuizItem.quizId == quiz.id).all()
    answer_map = {answer.itemId: answer for answer in data.answers}
 
    has_empty = any(
        item.id not in answer_map
        or answer_map[item.id].skipped
        or not (answer_map[item.id].answer or "").strip()
        for item in items
    )
    if has_empty and not data.confirmEmptyAsWrong:
        raise HTTPException(
            status_code=409,
            detail="There are empty/skipped questions. Confirm to count them as wrong.",
        )
 
    score = 0
    results: list[SM2ItemResult] = []
    has_real_answer = False
    now = _utcnow()
 
    for item in items:
        answer = answer_map.get(item.id)
        user_answer = (answer.answer if answer else None) or ""
        skipped = bool(answer.skipped) if answer else True
        duration = answer.durationSeconds if answer else None
 
        is_correct = normalize_answer(user_answer) == normalize_answer(item.correctAnswer)
        if user_answer.strip() and not skipped:
            has_real_answer = True
        if is_correct:
            score += 1
 
        word = (
            db.query(Word)
            .filter(
                Word.id == item.userWordId,
                Word.user_id == current_user.id,
                Word.is_active == 1,
            )
            .first()
        )
        if not word:
            continue
 
        quality = infer_quality(
            is_correct=is_correct,
            duration_seconds=duration,
            skipped=skipped or not user_answer.strip(),
        )
        snapshot = apply_modified_sm2(
            word,
            quality,
            reviewed_at=now,
            is_correct=is_correct,
            question_type=item.questionType,
            user_answer=user_answer,
        )
 
        item.userAnswer = user_answer
        item.isCorrect = is_correct
        item.durationSeconds = duration
        item.quality = quality
 
        results.append(
            SM2ItemResult(
                itemId=item.id,
                wordId=word.id,
                word=word.text,
                isCorrect=is_correct,
                quality=quality,
                sm2={
                    "new_ease_factor": snapshot.new_ease_factor,
                    "new_interval_days": snapshot.new_interval_days,
                    "next_review_label": snapshot.next_review_label,
                },
                oldScore=snapshot.old_score,
                newScore=snapshot.new_score,
                scoreDelta=snapshot.score_delta,
                oldRepeats=snapshot.old_repeats,
                newRepeats=snapshot.new_repeats,
                oldNextReviewDate=snapshot.old_next_review_at,
                newNextReviewDate=snapshot.new_next_review_at,
                status=snapshot.status,
                errorType=snapshot.error_type,
                learningInsight=snapshot.learning_insight,
                smartAction=snapshot.smart_action,
                achievementFlags=snapshot.achievement_flags,
            )
        )
 
    counts_for_streak, daily_streak = _update_streak(db, current_user.id, has_real_answer)
    quiz.score = score
    quiz.status = "submitted"
    quiz.submittedAt = now
    quiz.countsForStreak = counts_for_streak
    db.commit()
 
    return SM2SubmitResponse(
        quizId=quiz.id,
        score=score,
        total=len(items),
        countsForStreak=counts_for_streak,
        dailyStreak=daily_streak,
        results=results,
    )
 
 
@router.post("/quizzes/{quiz_id}/abandon")
def abandon_sm2_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = (
        db.query(SM2Quiz)
        .filter(SM2Quiz.id == quiz_id, SM2Quiz.userId == current_user.id)
        .first()
    )
    if not quiz:
        raise HTTPException(status_code=404, detail="SM2 quiz not found")
    if quiz.status == "in_progress":
        quiz.status = "abandoned"
        db.commit()
    return {"message": "SM2 quiz abandoned. SM2 and streak were not updated."}