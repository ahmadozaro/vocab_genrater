import json
import random
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.question_model import Question
from app.models.quiz_model import Quiz
from app.models.word_model import Word
from app.models.user_model import User
from app.schemas.question_schema import QuestionCreate, QuestionResponse
from app.schemas.quiz_schema import (
    QuizCreate,
    QuizResponse,
    QuizSubmitRequest,
    QuizSubmitResponse,
    QuizStartResponse,
)


router = APIRouter()


def _decode_options(options: str | None) -> list[str]:
    if not options:
        return []
    try:
        decoded: Any = json.loads(options)
        return decoded if isinstance(decoded, list) else []
    except json.JSONDecodeError:
        return []


def _question_response(question: Question) -> dict:
    return {
        "questionId": question.questionId,
        "questionText": question.questionText,
        "correctAnswer": question.correctAnswer,
        "options": _decode_options(question.options),
    }


def _get_user_quiz(db: Session, quiz_id: int, user_id: int) -> Quiz:
    quiz = db.query(Quiz).filter(Quiz.quizId == quiz_id, Quiz.userId == user_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz


def _format_start_question(question_text: str, options: list[str], correct: str) -> dict:
    return {
        "question": question_text,
        "options": options,
        "correctAnswer": correct,
    }


def _is_due_word(word: Word) -> bool:
    if not word.next_review_at:
        return False
    due_date = word.next_review_at
    if due_date.tzinfo is None:
        due_date = due_date.replace(tzinfo=timezone.utc)
    return due_date <= datetime.now(timezone.utc)


def _select_review_words(words: list[Word], limit: int = 10) -> list[Word]:
    selected: list[Word] = []
    seen: set[int] = set()

    groups = [
        sorted([w for w in words if _is_due_word(w)], key=lambda w: w.next_review_at or datetime.utcnow()),
        sorted(words, key=lambda w: (w.score if w.score is not None else 0, -w.id)),
        sorted(words, key=lambda w: w.id, reverse=True),
        sorted(words, key=lambda w: w.id),
    ]

    for group in groups:
        for word in group:
            if word.id in seen:
                continue
            selected.append(word)
            seen.add(word.id)
            if len(selected) >= min(limit, len(words)):
                return selected
    return selected


@router.post("/quizzes", response_model=QuizStartResponse)
def create_quiz(
    data: QuizCreate | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = data or QuizCreate()

    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.status != "pending")
        .order_by(Word.id.desc())
        .all()
    )
    if len(words) < 4:
        raise HTTPException(status_code=400, detail="Add at least 4 words to start a quiz")

    max_questions = min(len(words), data.questionsCount or min(10, len(words)))
    selected = words[:max_questions]

    questions_out: list[dict] = []
    question_rows: list[tuple[Word, str, list[str], str]] = []
    for w in selected:
        correct = w.text
        others = [x.text for x in words if x.id != w.id and x.text]
        distractors = random.sample(others, k=3)
        options = distractors + [correct]
        random.shuffle(options)

        question_text = (
            f"What is the English word for: {w.arabicMeaning}?" if w.arabicMeaning else f"What is the English word for: {w.text}?"
        )
        question_rows.append((w, question_text, options, correct))
        questions_out.append(_format_start_question(question_text, options, correct))

    if not question_rows:
        raise HTTPException(status_code=500, detail="Quiz generation failed: no questions were created")

    quiz = Quiz(
        quizType="recent",
        questionsCount=len(question_rows),
        score=0,
        userId=current_user.id,
    )
    db.add(quiz)
    db.flush()

    for w, question_text, options, correct in question_rows:
        question = Question(
            questionText=question_text,
            correctAnswer=correct,
            options=json.dumps(options, ensure_ascii=False),
            quizId=quiz.quizId,
            userWordId=w.id,
        )
        db.add(question)

    db.commit()
    db.refresh(quiz)

    return {"quiz_id": quiz.quizId, "questions": questions_out}


@router.get("/quizzes", response_model=list[QuizResponse])
def get_quizzes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(Quiz)
        .filter(Quiz.userId == current_user.id)
        .order_by(Quiz.date.desc())
        .all()
    )


@router.get("/quizzes/{quiz_id}", response_model=QuizResponse)
def get_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _get_user_quiz(db, quiz_id, current_user.id)


@router.post("/quizzes/ai-review", response_model=QuizStartResponse)
def create_ai_review_quiz(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Generate an AI-powered review quiz using a smart mix of words.
    Prefers recent and lower-score words, but includes a variety.
    """
    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.status != "pending")
        .all()
    )
    if len(words) < 4:
        raise HTTPException(status_code=400, detail="Add at least 4 words to start an AI review quiz")

    selected_words = _select_review_words(words, limit=10)
    word_texts_with_arabic = [f"{w.text} ({w.arabicMeaning or 'unknown'})" for w in selected_words if w.text]

    try:
        from app.services.ai_service import VocabGenAI

        if not settings.GEMINI_API_KEY:
            raise RuntimeError("GEMINI_API_KEY not configured")

        ai = VocabGenAI(api_key=settings.GEMINI_API_KEY)
        user_level = current_user.level or "A1"

        ai_result = ai.generate_review_quiz(word_texts_with_arabic, user_level)
        if ai_result.get("error"):
            raise RuntimeError(f"AI generation failed: {ai_result.get('details')}")

        ai_questions = ai_result.get("questions", [])
        if not ai_questions:
            raise RuntimeError("AI returned no questions")

    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI quiz generation failed: {str(e)}")

    questions_out: list[dict] = []
    valid_questions: list[tuple[str, list[str], str]] = []
    for ai_q in ai_questions:
        question_text = ai_q.get("question_text", "")
        options = ai_q.get("options", [])
        correct = ai_q.get("correct_answer", "")

        if not question_text or not isinstance(options, list) or len(options) != 4:
            raise HTTPException(status_code=502, detail="AI returned invalid quiz options")
        if correct not in options:
            raise HTTPException(status_code=502, detail="Correct answer not in options")

        clean_options = [str(option) for option in options]
        valid_questions.append((str(question_text), clean_options, str(correct)))
        questions_out.append(_format_start_question(str(question_text), clean_options, str(correct)))

    if not valid_questions:
        raise HTTPException(status_code=502, detail="AI returned no valid questions")

    quiz = Quiz(
        quizType="ai_review",
        questionsCount=len(valid_questions),
        score=0,
        userId=current_user.id,
    )
    db.add(quiz)
    db.flush()

    for question_text, options, correct in valid_questions:
        question = Question(
            questionText=question_text,
            correctAnswer=correct,
            options=json.dumps(options, ensure_ascii=False),
            quizId=quiz.quizId,
        )
        db.add(question)

    db.commit()
    db.refresh(quiz)

    return {"quiz_id": quiz.quizId, "questions": questions_out}


@router.post("/quizzes/{quiz_id}/questions", response_model=QuestionResponse)
def create_quiz_question(
    quiz_id: int,
    data: QuestionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = _get_user_quiz(db, quiz_id, current_user.id)
    question = Question(
        questionText=data.questionText,
        correctAnswer=data.correctAnswer,
        options=json.dumps(data.options, ensure_ascii=False),
        quizId=quiz.quizId,
    )
    db.add(question)
    quiz.questionsCount = (quiz.questionsCount or 0) + 1
    db.commit()
    db.refresh(question)
    return _question_response(question)


@router.get("/quizzes/{quiz_id}/questions", response_model=list[QuestionResponse])
def get_quiz_questions(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = _get_user_quiz(db, quiz_id, current_user.id)
    questions = (
        db.query(Question)
        .filter(Question.quizId == quiz.quizId)
        .order_by(Question.questionId.asc())
        .all()
    )
    return [_question_response(question) for question in questions]


@router.post("/quizzes/{quiz_id}/submit", response_model=QuizSubmitResponse)
def submit_quiz(
    quiz_id: int,
    data: QuizSubmitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = _get_user_quiz(db, quiz_id, current_user.id)
    questions = (
        db.query(Question)
        .filter(Question.quizId == quiz.quizId)
        .order_by(Question.questionId.asc())
        .all()
    )

    score = 0
    for index, question in enumerate(questions):
        if index < len(data.answers):
            question.userAnswer = data.answers[index]
            question.isCorrect = data.answers[index] == question.correctAnswer
        if question.isCorrect:
            score += 1

    quiz.score = score
    quiz.questionsCount = len(questions)
    quiz.status = "submitted"
    quiz.submittedAt = datetime.utcnow()
    db.commit()

    return QuizSubmitResponse(quizId=quiz.quizId, score=score, total=len(questions))
