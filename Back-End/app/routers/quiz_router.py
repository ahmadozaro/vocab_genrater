import json
import logging
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


QUESTION_TYPES = ["mcq", "fill", "tf"]
logger = logging.getLogger(__name__)
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
        "questionType": question.questionType or "mcq",
    }


def _get_user_quiz(db: Session, quiz_id: int, user_id: int) -> Quiz:
    quiz = db.query(Quiz).filter(Quiz.quizId == quiz_id, Quiz.userId == user_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz


def _format_start_question(question_text: str, options: list[str], correct: str, qtype: str = "mcq") -> dict:
    return {
        "question": question_text,
        "options": options,
        "correctAnswer": correct,
        "questionType": qtype,
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


def _generate_mcq(words: list[Word], selected: Word, all_texts: list[str]) -> tuple[str, list[str], str]:
    correct = selected.text
    others = [t for t in all_texts if t != correct]
    distractors = random.sample(others, min(3, len(others)))
    while len(distractors) < 3:
        distractors.append(f"option{len(distractors)}")
    options = distractors + [correct]
    random.shuffle(options)
    meaning = selected.arabicMeaning
    question_text = f"What is the English word for: {meaning}?" if meaning else f"What word means: {correct}?"
    return question_text, options, correct


def _generate_fill_in_blank(words: list[Word], selected: Word) -> tuple[str, list[str], str]:
    correct = selected.text
    meaning = selected.arabicMeaning
    if meaning:
        question_text = f'Fill in the blank: "The English word for "{meaning}" is ____."'
    else:
        question_text = f'Fill in the blank: "The word ____ means {correct}."'
    return question_text, [], correct


def _generate_true_false(words: list[Word], selected: Word, all_texts: list[str]) -> tuple[str, list[str], str]:
    correct = selected.text
    meaning = selected.arabicMeaning
    is_true = random.choice([True, False])
    if is_true:
        display_text = correct
        display_meaning = meaning or "a vocabulary word"
        statement = f'Is the word "{display_text}" correctly defined as "{display_meaning}"?'
    else:
        other = random.choice([t for t in all_texts if t != correct]) if len(all_texts) > 1 else "another word"
        display_meaning = meaning or "a vocabulary word"
        statement = f'Is the word "{other}" correctly defined as "{display_meaning}"?'
    return statement, ["True", "False"], "True" if is_true else "False"


def _normalize_answer(s: str | None) -> str:
    if not s:
        return ""
    return " ".join(s.strip().lower().split())


# ─── CREATE QUIZ (recent words, mixed types) ─────────────────────


@router.post("/quizzes", response_model=QuizStartResponse)
def create_quiz(
    data: QuizCreate | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = data or QuizCreate()

    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.is_active == 1, Word.status != "pending")
        .order_by(Word.id.desc())
        .all()
    )
    if len(words) < 4:
        raise HTTPException(status_code=400, detail="Add at least 4 words to start a quiz")

    max_questions = min(len(words), data.questionsCount or min(10, len(words)))
    selected = words[:max_questions]
    all_texts = [w.text for w in words if w.text]

    questions_out: list[dict] = []
    question_rows: list[tuple[Word, str, list[str], str, str]] = []

    for i, w in enumerate(selected):
        r = i % len(QUESTION_TYPES)
        if r == 1:
            q_text, opts, correct = _generate_fill_in_blank(words, w)
            qtype = "fill"
        elif r == 2:
            q_text, opts, correct = _generate_true_false(words, w, all_texts)
            qtype = "tf"
        else:
            q_text, opts, correct = _generate_mcq(words, w, all_texts)
            qtype = "mcq"
        question_rows.append((w, q_text, opts, correct, qtype))
        questions_out.append(_format_start_question(q_text, opts, correct, qtype))

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

    for w, q_text, opts, correct, qtype in question_rows:
        question = Question(
            questionText=q_text,
            correctAnswer=correct,
            options=json.dumps(opts, ensure_ascii=False),
            quizId=quiz.quizId,
            userWordId=w.id,
            questionType=qtype,
        )
        db.add(question)

    db.commit()
    db.refresh(quiz)

    return {"quiz_id": quiz.quizId, "questions": questions_out}


# ─── GET QUIZ HISTORY ────────────────────────────────────────────


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


# ─── AI REVIEW QUIZ ──────────────────────────────────────────────


@router.post("/quizzes/ai-review", response_model=QuizStartResponse)
def create_ai_review_quiz(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    words = (
        db.query(Word)
        .filter(Word.user_id == current_user.id, Word.is_active == 1, Word.status != "pending")
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
            logger.warning("AI quiz generation failed; using fallback: %.200s", str(exc))

    if not ai_questions:
        ai_questions = VocabGenAI._fallback_quiz_questions(word_dicts, min(10, len(word_dicts)))

    questions_out: list[dict] = []
    valid_questions: list[dict] = []
    for q in ai_questions:
        question_text = q.get("questionText", "")
        options = q.get("options", [])
        correct = q.get("correctAnswer", "")
        qtype = q.get("questionType", "mcq")

        if not question_text:
            continue
        if qtype in ("mcq", "multiple_choice") and (not isinstance(options, list) or len(options) < 2 or correct not in options):
            continue
        if qtype in ("fill", "fill_in_blank") and not correct:
            continue
        if qtype in ("tf", "true_false") and set(options) != {"True", "False"}:
            continue
        # Map legacy AI type names to new short names
        qtype_map = {"multiple_choice": "mcq", "fill_in_blank": "fill", "true_false": "tf"}
        qtype = qtype_map.get(qtype, qtype)
        clean_options = [str(o) for o in options]
        valid_questions.append({
            "questionText": str(question_text),
            "options": clean_options,
            "correctAnswer": str(correct),
            "questionType": qtype,
        })
        questions_out.append(_format_start_question(str(question_text), clean_options, str(correct), qtype))

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

    for q in valid_questions:
        question = Question(
            questionText=q["questionText"],
            correctAnswer=q["correctAnswer"],
            options=json.dumps(q["options"], ensure_ascii=False),
            quizId=quiz.quizId,
            questionType=q["questionType"],
        )
        db.add(question)

    db.commit()
    db.refresh(quiz)

    return {"quiz_id": quiz.quizId, "questions": questions_out}


# ─── SUBMIT QUIZ ─────────────────────────────────────────────────


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
            qtype = question.questionType or "mcq"
            if qtype == "fill":
                user_ans = _normalize_answer(data.answers[index])
                correct_ans = _normalize_answer(question.correctAnswer)
                question.isCorrect = user_ans == correct_ans
            else:
                question.isCorrect = data.answers[index] == question.correctAnswer
        if question.isCorrect:
            score += 1

    quiz.score = score
    quiz.questionsCount = len(questions)
    quiz.status = "submitted"
    quiz.submittedAt = datetime.utcnow()
    db.commit()

    return QuizSubmitResponse(quizId=quiz.quizId, score=score, total=len(questions))
