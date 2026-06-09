
import json
import logging
from datetime import datetime, timezone
 
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
 
from app.auth import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.question_model import Question
from app.models.quiz_model import Quiz
from app.models.word_model import Word
from app.models.user_model import User
from app.schemas.question_schema import QuestionResponse
from app.schemas.quiz_schema import (
    QuizCreate,
    QuizResponse,
    QuizSubmitRequest,
    QuizSubmitResponse,
    QuizStartResponse,
)
from app.services.ai_service import VocabGenAI
from app.utils.quiz_helpers import (
    build_question_rows,
    normalize_answer,
    grade_for,
)
 
 
logger = logging.getLogger(__name__)
router = APIRouter()
 
 
def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)
 
 
def _decode_options(options: str | None) -> list[str]:
    if not options:
        return []
    try:
        decoded = json.loads(options)
        return decoded if isinstance(decoded, list) else []
    except json.JSONDecodeError:
        return []
 
 
def _get_user_quiz(db: Session, quiz_id: int, user_id: int) -> Quiz:
    quiz = db.query(Quiz).filter(Quiz.quizId == quiz_id, Quiz.userId == user_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz
 
 
def _word_explanation(word: Word | None) -> dict:
    if not word:
        return {
            "correctMeaning": None,
            "exampleSentence": None,
            "learningTip": "Review this answer in context before the next quiz.",
        }
    example = word.sentences[0].sentence_en if word.sentences else None
    meaning = word.arabicMeaning or word.definition
    return {
        "correctMeaning": meaning,
        "exampleSentence": example,
        "learningTip": f"Link '{word.text}' with a short sentence you can say aloud.",
    }
 
 
def _format_start_question(
    question_text: str,
    options: list[str],
    correct: str,
    qtype: str = "mcq",
    word: Word | None = None,
) -> dict:
    return {
        "question": question_text,
        "options": options,
        "correctAnswer": correct,
        "questionType": qtype,
        **_word_explanation(word),
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
 
 
# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
 
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
    question_rows = build_question_rows(words, selected)
 
    if not question_rows:
        raise HTTPException(status_code=500, detail="Quiz generation failed: no questions were created")
 
    questions_out = [
        _format_start_question(q_text, opts, correct, qtype, word=w)
        for w, q_text, opts, correct, qtype in question_rows
    ]
 
    quiz = Quiz(
        quizType="recent",
        questionsCount=len(question_rows),
        score=0,
        userId=current_user.id,
    )
    db.add(quiz)
    db.flush()
 
    for w, q_text, opts, correct, qtype in question_rows:
        db.add(Question(
            questionText=q_text,
            correctAnswer=correct,
            options=json.dumps(opts, ensure_ascii=False),
            quizId=quiz.quizId,
            userWordId=w.id,
            questionType=qtype,
        ))
 
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
        .filter(Word.user_id == current_user.id, Word.is_active == 1, Word.status != "pending")
        .all()
    )
    if len(words) < 4:
        raise HTTPException(status_code=400, detail="Add at least 4 words to start an AI review quiz")
 
    selected_words = _select_quiz_words(words, limit=10)
    word_dicts = [
        {
            "text": w.text,
            "arabicMeaning": w.arabicMeaning or "",
            "definition": w.definition or "",
            "exampleSentence": w.sentences[0].sentence_en if w.sentences else "",
            "wordId": w.id,
        }
        for w in selected_words if w.text
    ]
 
    ai_questions: list[dict] | None = None
    if settings.GROQ_API_KEY:
        try:
            with VocabGenAI(api_key=settings.GROQ_API_KEY, model=settings.GROQ_MODEL) as ai:
                ai_questions = ai.generate_quiz_questions(word_dicts, count=min(10, len(word_dicts)))
        except Exception as exc:
            logger.warning("AI quiz generation failed; using fallback: %.200s", str(exc))
 
    if not ai_questions:
        try:
            ai_questions = VocabGenAI._fallback_quiz_questions(word_dicts, min(10, len(word_dicts)))
        except Exception as exc:
            logger.warning("AI fallback quiz generation failed; using local generator: %.200s", str(exc))
            ai_questions = []
 
    valid_questions: list[dict] = []
    words_by_id = {w.id: w for w in selected_words}
    qtype_map = {"multiple_choice": "mcq", "true_false": "tf"}
 
    for q in ai_questions:
        question_text = q.get("questionText", "")
        options = q.get("options", [])
        correct = q.get("correctAnswer", "")
        qtype = qtype_map.get(q.get("questionType", "mcq"), q.get("questionType", "mcq"))
 
        if not question_text:
            continue
        if qtype == "mcq" and (not isinstance(options, list) or len(options) != 4 or correct not in options):
            continue
        if qtype == "tf" and set(options) != {"True", "False"}:
            continue
        if qtype not in {"mcq", "tf"}:
            continue
 
        try:
            source_word_id = int(q.get("wordId")) if q.get("wordId") is not None else None
        except (TypeError, ValueError):
            source_word_id = None
 
        valid_questions.append({
            "questionText": str(question_text),
            "options": [str(o) for o in options],
            "correctAnswer": str(correct),
            "questionType": qtype,
            "word": words_by_id.get(source_word_id),
        })
 
    if not valid_questions:
        question_rows = build_question_rows(words, selected_words)
        valid_questions = [
            {"questionText": q_text, "options": opts, "correctAnswer": correct, "questionType": qtype, "word": w}
            for w, q_text, opts, correct, qtype in question_rows
        ]
 
    questions_out = [
        _format_start_question(q["questionText"], q["options"], q["correctAnswer"], q["questionType"], word=q.get("word"))
        for q in valid_questions
    ]
 
    quiz = Quiz(quizType="ai_review", questionsCount=len(valid_questions), score=0, userId=current_user.id)
    db.add(quiz)
    db.flush()
 
    for q in valid_questions:
        db.add(Question(
            questionText=q["questionText"],
            correctAnswer=q["correctAnswer"],
            options=json.dumps(q["options"], ensure_ascii=False),
            quizId=quiz.quizId,
            userWordId=q["word"].id if q.get("word") else None,
            questionType=q["questionType"],
        ))
 
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
    breakdown: list[dict] = []
    for index, question in enumerate(questions):
        user_answer = data.answers[index] if index < len(data.answers) else ""
        question.userAnswer = user_answer
        qtype = question.questionType or "mcq"
        if qtype == "fill":
            question.isCorrect = normalize_answer(user_answer) == normalize_answer(question.correctAnswer)
        else:
            question.isCorrect = user_answer == question.correctAnswer
        if question.isCorrect:
            score += 1
        breakdown.append({
            "questionText": question.questionText,
            "userAnswer": question.userAnswer or "",
            "correctAnswer": question.correctAnswer or "",
            "isCorrect": bool(question.isCorrect),
        })
 
    quiz.score = score
    quiz.questionsCount = len(questions)
    quiz.status = "submitted"
    quiz.submittedAt = _utcnow()
    db.commit()
 
    total = len(questions)
    percentage = round((score / total) * 100, 2) if total else 0
    return QuizSubmitResponse(
        quizId=quiz.quizId,
        score=score,
        total=total,
        percentage=percentage,
        grade=grade_for(percentage),
        breakdown=breakdown,
    )