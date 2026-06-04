import json
import random
from datetime import datetime
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
from app.services.ai_service import VocabGenAI


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


def _select_quiz_words(words: list[Word], limit: int = 10) -> list[Word]:
    selected: list[Word] = []
    seen: set[int] = set()

    groups = [
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


@router.post("/quizzes/ai-review", response_model=QuizStartResponse)
def create_ai_review_quiz(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.status != "pending")
        .all()
    )
    if len(words) < 4:
        raise HTTPException(status_code=400, detail="Add at least 4 words to start an AI review quiz")

    selected_words = _select_quiz_words(words, limit=10)
    word_dicts = [
        {"text": w.text, "arabicMeaning": w.arabicMeaning or "", "wordId": w.id}
        for w in selected_words if w.text
    ]

    ai_questions: list[dict] | None = None
    if settings.GROQ_API_KEY:
        try:
            ai = VocabGenAI(api_key=settings.GROQ_API_KEY, model=settings.GROQ_MODEL)
            ai_questions = ai.generate_quiz_questions(word_dicts, count=min(10, len(word_dicts)))
        except Exception as exc:
            logger = logging.getLogger(__name__)
            logger.warning("AI quiz generation failed; using fallback: %.200s", str(exc))

    if not ai_questions:
        ai_questions = VocabGenAI._fallback_quiz_questions(word_dicts, min(10, len(word_dicts)))

    questions_out: list[dict] = []
    valid_questions: list[tuple[str, list[str], str]] = []
    for q in ai_questions:
        question_text = q.get("questionText", "")
        options = q.get("options", [])
        correct = q.get("correctAnswer", "")

        if not question_text or not isinstance(options, list) or len(options) != 4:
            continue
        if correct not in options:
            continue
        clean_options = [str(o) for o in options]
        valid_questions.append((str(question_text), clean_options, str(correct)))
        questions_out.append(_format_start_question(str(question_text), clean_options, str(correct)))

    if not valid_questions:
        raise HTTPException(status_code=500, detail="Quiz generation failed: no valid questions")

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


@router.post("/quizzes/{quiz_id}/submit", response_model=QuizSubmitResponse)
def submit_quiz(
    quiz_id: int,
    data: QuizSubmitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    quiz = _get_user_quiz(db, quiz_id, current_user.id)
    if quiz.status != "in_progress":
        raise HTTPException(status_code=400, detail="This quiz was already submitted")
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
