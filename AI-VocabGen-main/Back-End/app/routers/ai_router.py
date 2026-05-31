import logging
from typing import List

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth import get_current_user
from app.core.config import settings
from app.models.user_model import User
from app.services.translation_service import TranslationService

router = APIRouter(prefix="/ai", tags=["AI"])
logger = logging.getLogger(__name__)


class SuggestWordsRequest(BaseModel):
    level: str = "B1"
    interests: List[str] = []
    existingWords: List[str] = []
    limit: int = 6


def _fallback_words(existing: set[str], limit: int) -> list[str]:
    pool = [
        "improve", "focus", "review", "daily", "memory", "practice",
        "goal", "useful", "simple", "example", "progress", "habit",
    ]
    return [w for w in pool if w.lower() not in existing][:limit]


def _safe_error(exc: Exception | str | None) -> str | None:
    if exc is None:
        return None
    text = str(exc)
    return text[:240]


@router.get("/health")
def ai_health():
    configured = bool(settings.GEMINI_API_KEY)
    response = {
        "configured": configured,
        "model": settings.GEMINI_MODEL,
        "ok": False,
        "error": None,
    }
    if not configured:
        response["error"] = "GEMINI_API_KEY is not configured"
        return response

    try:
        from app.services.ai_service import VocabGenAI

        health = VocabGenAI(api_key=settings.GEMINI_API_KEY).health_check()
        response["ok"] = bool(health.get("ok"))
        response["error"] = _safe_error(health.get("error"))
    except Exception as exc:
        logger.exception("AI health check failed")
        response["ok"] = False
        response["error"] = _safe_error(exc)
    return response


@router.post("/suggest-words")
def suggest_words(
    data: SuggestWordsRequest,
    current_user: User = Depends(get_current_user),
):
    existing = {w.strip().lower() for w in data.existingWords if w.strip()}
    level = data.level or current_user.level or "B1"
    interests = data.interests or ["general vocabulary"]
    limit = max(1, min(10, data.limit or 6))

    words: list[str] = []
    if settings.GEMINI_API_KEY:
        try:
            from app.services.ai_service import VocabGenAI

            ai = VocabGenAI(api_key=settings.GEMINI_API_KEY)
            result = ai.suggest_smart_words(level=level, interests=interests, excluded_words=list(existing))
            if isinstance(result, list):
                words = [str(w) for w in result if str(w).strip() and str(w).strip().lower() not in existing]
            elif isinstance(result, dict) and result.get("error"):
                logger.error("AI suggestions failed: %s", result.get("details") or result.get("error"))
        except Exception as exc:
            logger.exception("AI suggestions failed; using fallback words")
            words = []

    if not words:
        logger.info("Using fallback AI suggestions for level=%s interests=%s", level, interests)
        words = _fallback_words(existing, limit)

    service = TranslationService()
    suggestions = []
    for word in words[:limit]:
        translation = service.translate(word)
        suggestions.append(
            {
                "text": word,
                "definition": "AI-generated details can be loaded when saving or looking up the word.",
                "arabicMeaning": translation.translation or "",
                "difficulty": "medium",
                "example": f"I want to use the word {word} in a real sentence.",
            }
        )
    return suggestions
