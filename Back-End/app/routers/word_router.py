from ctypes import PyDLL


PyDLL
from datetime import datetime, time, timezone
import logging
 
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
 
from app.auth import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.user_model import User
from app.models.word_model import DictionaryWord, Word, WordExample, WordTranslation
from app.schemas.sentence_schema import SentenceCreate, SentenceResponse
from app.schemas.word_schema import (
    WordCreate,
    WordLookupRequest,
    WordLookupResponse,
    WordResponse,
    WordUpdate,
)
from app.services.translation_service import TranslationService
from app.services.ai_service import VocabGenAI
from app.utils.security import ALGORITHM, SECRET_KEY
 
 
router = APIRouter()
logger = logging.getLogger(__name__)
optional_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login", auto_error=False)
DAILY_ACTIVE_NEW_WORDS_LIMIT = 10
 
 
def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)
 
 
def _clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None
 
 
def _normalize_word(value: str | None) -> str:
    return " ".join((value or "").strip().lower().split())
 
 
def _translate_only(word_text: str) -> dict:
    normalized = _normalize_word(word_text)
    if not normalized:
        raise HTTPException(status_code=400, detail="Text is required")
    result = TranslationService().translate(normalized)
    return {
        "text": word_text.strip(),
        "arabicMeaning": result.translation,
        "translationAr": result.translation,
        "provider": result.provider or "fallback",
    }
 
 
def _word_response(word: Word) -> dict:
    examples = [
        example.sentence_en
        for example in (word.dictionary_word.examples if word.dictionary_word else [])
    ]
    return {
        "wordId": word.id,
        "dictionaryWordId": word.word_id,
        "text": word.text,
        "normalizedText": word.normalizedText,
        "arabicMeaning": word.arabicMeaning,
        "translationAr": word.translationAr,
        "translationProvider": word.translationProvider,
        "aiMeaningAr": None,
        "aiDefinitionEn": word.definition,
        "audio": None,
        "sm2Repeats": word.sm2_repeats or 0,
        "sm2EaseFactor": float(word.sm2_ease_factor or 2.5),
        "sm2IntervalDays": word.sm2_interval_days or 0,
        "nextReviewDate": word.next_review_at,
        "lastReviewedAt": word.last_reviewed_at,
        "lastQuality": None,
        "correctStreak": word.correct_streak or 0,
        "wrongStreak": word.wrong_streak or 0,
        "score": word.score or 0,
        "status": word.status or "new",
        "isActive": bool(word.is_active),
        "activationDate": word.activation_date,
        "source": None,
        "userId": word.user_id,
        "addedAt": word.added_at,
        "examples": examples,
    }
 
 
def _get_optional_user(
    token: str | None = Depends(optional_oauth2_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    if not token:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
    except JWTError:
        return None
    if user_id is None:
        return None
    return db.query(User).filter(User.id == user_id).first()
 
 
def _get_ai_details(word_text: str, level: str) -> dict:
    if not settings.GROQ_API_KEY:
        return {}
    try:
        with VocabGenAI(api_key=settings.GROQ_API_KEY, model=settings.GROQ_MODEL) as ai:
            details = ai.generate_word_details(word=word_text, level=level)
        if not isinstance(details, dict):
            return {}
        return {
            "word": word_text,
            "arabic_meaning": details.get("contextual_meaning_ar", ""),
            "english_definition": details.get("definition_en", f"A vocabulary word: {word_text}."),
            "context_sentence": details.get("example_sentence_en", f"I learned the word {word_text} today."),
            "arabic_context_translation": details.get("example_sentence_ar", ""),
        }
    except Exception as exc:
        logger.warning("AI details unavailable for %s: %.200s", word_text, str(exc))
        return {}
 
 
def _normalize_ai_lookup(word_text: str, details: dict) -> dict:
    example = _clean_text(details.get("context_sentence"))
    return {
        "text": _clean_text(details.get("word")) or word_text,
        "aiMeaningAr": _clean_text(details.get("arabic_meaning")),
        "definition": _clean_text(details.get("english_definition")),
        "examples": [example] if example else [],
        "exampleAr": _clean_text(details.get("arabic_context_translation")),
        "source": "ai",
    }
 
 
def _get_user_word(db: Session, word_id: int, user_id: int) -> Word:
    word = (
        db.query(Word)
        .filter(Word.id == word_id, Word.user_id == user_id, Word.is_active == 1)
        .first()
    )
    if not word:
        raise HTTPException(status_code=404, detail="Word not found")
    return word
 
 
def _today_active_new_words_count(db: Session, user_id: int) -> int:
    now = _utcnow()
    today_start = datetime.combine(now.date(), time.min)
    today_end = datetime.combine(now.date(), time.max)
    return (
        db.query(Word)
        .filter(
            Word.user_id == user_id,
            Word.is_active == 1,
            Word.status != "pending",
            Word.activation_date >= today_start,
            Word.activation_date <= today_end,
        )
        .count()
    )
 
 
def _try_activate_pending_words(db: Session, user_id: int) -> int:
    available = DAILY_ACTIVE_NEW_WORDS_LIMIT - _today_active_new_words_count(db, user_id)
    if available <= 0:
        return 0
    pending_words = (
        db.query(Word)
        .filter(Word.user_id == user_id, Word.is_active == 1, Word.status == "pending")
        .order_by(Word.id.asc())
        .limit(available)
        .all()
    )
    now = _utcnow()
    for word in pending_words:
        word.status = "new"
        word.activation_date = now
        word.next_review_at = now
    return len(pending_words)
 
 
# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
 
@router.get("/words/translate-instant")
def instant_translate_word_get(text: str = Query(..., min_length=1)):
    return _translate_only(text)
 
 
@router.post("/words/lookup", response_model=WordLookupResponse)
def lookup_word(
    data: WordLookupRequest,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(_get_optional_user),
):
    word_text = _clean_text(data.text)
    if not word_text:
        raise HTTPException(status_code=400, detail="Word text is required")
 
    level = (
        _clean_text(data.level)
        or _clean_text(current_user.level if current_user else None)
        or "A1"
    )
 
    translation = TranslationService().translate(word_text)
    ai_lookup: dict = {}
    try:
        ai_lookup = _normalize_ai_lookup(word_text, _get_ai_details(word_text, level))
    except Exception as exc:
        logger.warning("Word lookup AI details unavailable for %s: %.200s", word_text, str(exc))
 
    return {
        "text": ai_lookup.get("text") or word_text,
        "arabicMeaning": translation.translation or ai_lookup.get("aiMeaningAr"),
        "translationAr": translation.translation,
        "translationProvider": translation.provider,
        "aiMeaningAr": ai_lookup.get("aiMeaningAr"),
        "definition": ai_lookup.get("definition"),
        "examples": ai_lookup.get("examples", []),
        "source": "translation+ai" if ai_lookup else "translation",
    }
 
 
@router.post("/words", response_model=WordResponse)
def create_word(
    word: WordCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    word_text = _clean_text(word.text)
    normalized = _normalize_word(word_text)
    if not normalized:
        raise HTTPException(status_code=400, detail="Word text is required")
 
    _try_activate_pending_words(db, current_user.id)
 
    dictionary_word = (
        db.query(DictionaryWord)
        .filter(DictionaryWord.normalized_text == normalized)
        .first()
    )
    if dictionary_word is None:
        dictionary_word = DictionaryWord(text=word_text, normalized_text=normalized)
        db.add(dictionary_word)
        db.flush()
 
    existing_user_word = (
        db.query(Word)
        .filter(Word.word_id == dictionary_word.id, Word.user_id == current_user.id)
        .first()
    )
    if existing_user_word and existing_user_word.is_active:
        raise HTTPException(status_code=400, detail="Word already exists")
 
    translation = TranslationService().translate(word_text)
    requested_examples = [
        example.strip()
        for example in word.examples
        if isinstance(example, str) and example.strip()
    ]
    generated_sentence = _clean_text(word.generatedSentence)
    if generated_sentence:
        requested_examples.append(generated_sentence)
 
    ai_lookup: dict = {}
    try:
        details = _get_ai_details(word_text, current_user.level or "A1")
        ai_lookup = _normalize_ai_lookup(word_text, details)
        if not requested_examples:
            requested_examples = ai_lookup.get("examples", [])
    except Exception as exc:
        logger.warning("Create word AI details unavailable for %s: %.200s", word_text, str(exc))
 
    if ai_lookup.get("definition") and not dictionary_word.definition_en:
        dictionary_word.definition_en = ai_lookup.get("definition")
    elif not dictionary_word.definition_en:
        dictionary_word.definition_en = f"A vocabulary word: {word_text}."
 
    if not requested_examples:
        requested_examples = [f'I learned the word "{word_text}" today.']
 
    active_count = _today_active_new_words_count(db, current_user.id)
    is_pending = active_count >= DAILY_ACTIVE_NEW_WORDS_LIMIT
    now = _utcnow()
 
    manual_translation = _clean_text(word.arabicMeaning) or _clean_text(word.translationAr)
    primary_translation = manual_translation or translation.translation or ai_lookup.get("aiMeaningAr")
    translation_provider = (
        "manual"
        if manual_translation
        else (translation.provider if translation.translation else "fallback")
    )
 
    if primary_translation:
        db.query(WordTranslation).filter(
            WordTranslation.word_id == dictionary_word.id
        ).update({"is_primary": 0}, synchronize_session=False)
 
        existing_translation = (
            db.query(WordTranslation)
            .filter(
                WordTranslation.word_id == dictionary_word.id,
                WordTranslation.provider == translation_provider,
            )
            .first()
        )
        if existing_translation:
            existing_translation.translation_text = primary_translation
            existing_translation.is_primary = True
        else:
            db.add(WordTranslation(
                word_id=dictionary_word.id,
                translation_text=primary_translation,
                provider=translation_provider,
                is_primary=True,
            ))
 
    if existing_user_word and not existing_user_word.is_active:
        db_word = existing_user_word
        db_word.is_active = 1
        db_word.status = "pending" if is_pending else "new"
        db_word.activation_date = None if is_pending else now
        db_word.next_review_at = None if is_pending else now
        db_word.added_at = now
        db_word.score = 0
        db_word.sm2_repeats = 0
        db_word.sm2_ease_factor = 2.5
        db_word.sm2_interval_days = 0
        db_word.last_reviewed_at = None
        db_word.correct_streak = 0
        db_word.wrong_streak = 0
    else:
        db_word = Word(
            user_id=current_user.id,
            word_id=dictionary_word.id,
            status="pending" if is_pending else "new",
            activation_date=None if is_pending else now,
            next_review_at=None if is_pending else now,
            is_active=1,
        )
        db.add(db_word)
    db.flush()
 
    for example in requested_examples:
        exists = any(
            ex.sentence_en.strip().lower() == example.strip().lower()
            for ex in dictionary_word.examples
        )
        if not exists:
            db.add(WordExample(
                word_id=dictionary_word.id,
                sentence_en=example,
                sentence_ar=ai_lookup.get("exampleAr"),
            ))
 
    db.commit()
    db.refresh(db_word)
    return _word_response(db_word)
 
 
@router.get("/words")
def get_words(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    search: str | None = Query(None),
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Always returns a unified dict:
        { "words": [...], "total": int, "page": int, "pages": int }
 
    (Previously returned a bare list on page=1 with no filters — that
    inconsistency caused extra branching on the Flutter side.)
    """
    _try_activate_pending_words(db, current_user.id)
    db.commit()
 
    query = (
        db.query(Word)
        .join(DictionaryWord)
        .filter(Word.user_id == current_user.id, Word.is_active == 1)
    )
    if status:
        query = query.filter(Word.status == status)
    if search:
        normalized_search = f"%{_normalize_word(search)}%"
        query = query.filter(
            or_(
                DictionaryWord.normalized_text.ilike(normalized_search),
                DictionaryWord.text.ilike(f"%{search.strip()}%"),
            )
        )
 
    total = query.count()
    pages = max(1, (total + limit - 1) // limit)
    words = (
        query.order_by(Word.id.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )
 
    return {
        "words": [_word_response(word) for word in words],
        "total": total,
        "page": page,
        "pages": pages,
    }
 
 
@router.get("/words/{word_id}", response_model=WordResponse)
def get_word(
    word_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _word_response(_get_user_word(db, word_id, current_user.id))
 
 
@router.put("/words/{word_id}", response_model=WordResponse)
def update_word(
    word_id: int,
    data: WordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    word = _get_user_word(db, word_id, current_user.id)
    updates = (
        data.model_dump(exclude_unset=True)
        if hasattr(data, "model_dump")
        else data.dict(exclude_unset=True)
    )
    if "text" in updates and updates["text"]:
        raise HTTPException(
            status_code=400,
            detail="Changing word text is not supported; add a new word instead",
        )
    for field, value in updates.items():
        if field == "nextReviewDate":
            word.next_review_at = value
        elif field in {"score", "status"}:
            setattr(word, field, value)
    db.commit()
    db.refresh(word)
    return _word_response(word)
 
 
@router.delete("/words/{word_id}")
def delete_word(
    word_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    word = _get_user_word(db, word_id, current_user.id)
    word.is_active = 0
    db.commit()
    return {"message": "Word removed from your words"}
 
 
@router.post("/words/{word_id}/restore", response_model=WordResponse)
def restore_word(
    word_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    word = db.query(Word).filter(Word.id == word_id, Word.user_id == current_user.id).first()
    if not word:
        raise HTTPException(status_code=404, detail="Word not found")
    word.is_active = 1
    if word.status == "pending":
        word.activation_date = None
        word.next_review_at = None
    elif not word.next_review_at:
        word.next_review_at = _utcnow()
    db.commit()
    db.refresh(word)
    return _word_response(word)
 
 
@router.post("/words/{word_id}/sentences", response_model=SentenceResponse)
def create_word_sentence(
    word_id: int,
    sentence: SentenceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    word = _get_user_word(db, word_id, current_user.id)
    sentence_text = sentence.text.strip()
    if not sentence_text:
        raise HTTPException(status_code=400, detail="Sentence text is required")
    exists = (
        db.query(WordExample)
        .filter(
            WordExample.word_id == word.word_id,
            WordExample.sentence_en == sentence_text,
        )
        .first()
    )
    if exists:
        return {"sentenceId": exists.id, "text": exists.sentence_en, "wordId": word.id}
    db_sentence = WordExample(sentence_en=sentence_text, word_id=word.word_id)
    db.add(db_sentence)
    db.commit()
    db.refresh(db_sentence)
    return {"sentenceId": db_sentence.id, "text": db_sentence.sentence_en, "wordId": word.id}
 
 
@router.get("/words/{word_id}/sentences", response_model=list[SentenceResponse])
def get_word_sentences(
    word_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    word = _get_user_word(db, word_id, current_user.id)
    return [
        {"sentenceId": ex.id, "text": ex.sentence_en, "wordId": word.id}
        for ex in db.query(WordExample).filter(WordExample.word_id == word.word_id).all()
    ]