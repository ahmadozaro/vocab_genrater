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
    limit: int = 20


FALLBACK_WORDS = [
    {"text": "improve", "arabicMeaning": "يحسن", "definition": "To make something better", "difficulty": "easy", "example": "I want to improve my English."},
    {"text": "focus", "arabicMeaning": "يركز", "definition": "To give full attention to something", "difficulty": "easy", "example": "Please focus on your work."},
    {"text": "review", "arabicMeaning": "يراجع", "definition": "To look at something again", "difficulty": "easy", "example": "Let me review this chapter."},
    {"text": "practice", "arabicMeaning": "ممارسة", "definition": "To do something many times to get better", "difficulty": "easy", "example": "Practice makes perfect."},
    {"text": "achieve", "arabicMeaning": "يحقق", "definition": "To successfully reach a goal", "difficulty": "medium", "example": "She worked hard to achieve her dream."},
    {"text": "benefit", "arabicMeaning": "فائدة", "definition": "An advantage or positive result", "difficulty": "medium", "example": "Exercise has many health benefits."},
    {"text": "challenge", "arabicMeaning": "تحدي", "definition": "Something difficult that tests your ability", "difficulty": "medium", "example": "Learning a new language is a big challenge."},
    {"text": "discover", "arabicMeaning": "يكتشف", "definition": "To find something for the first time", "difficulty": "medium", "example": "Scientists discover new things every day."},
    {"text": "establish", "arabicMeaning": "يؤسس", "definition": "To start or create something", "difficulty": "hard", "example": "The company was established in 2010."},
    {"text": "frequent", "arabicMeaning": "متكرر", "definition": "Happening often", "difficulty": "medium", "example": "She makes frequent trips to the library."},
    {"text": "generate", "arabicMeaning": "يولد", "definition": "To produce or create something", "difficulty": "medium", "example": "The wind turbines generate electricity."},
    {"text": "identify", "arabicMeaning": "يحدد", "definition": "To recognize and name something", "difficulty": "medium", "example": "Can you identify the problem?"},
    {"text": "maintain", "arabicMeaning": "يحافظ", "definition": "To keep something in good condition", "difficulty": "medium", "example": "It is important to maintain your health."},
    {"text": "negotiate", "arabicMeaning": "يتفاوض", "definition": "To discuss to reach an agreement", "difficulty": "hard", "example": "They need to negotiate a new contract."},
    {"text": "obtain", "arabicMeaning": "يحصل على", "definition": "To get or acquire something", "difficulty": "medium", "example": "You need to obtain permission first."},
    {"text": "persuade", "arabicMeaning": "يقنع", "definition": "To make someone believe or do something", "difficulty": "hard", "example": "She persuaded him to join the team."},
    {"text": "require", "arabicMeaning": "يتطلب", "definition": "To need something", "difficulty": "medium", "example": "This job requires experience."},
    {"text": "significant", "arabicMeaning": "مهم", "definition": "Important or large enough to notice", "difficulty": "medium", "example": "There was a significant increase in sales."},
    {"text": "tradition", "arabicMeaning": "تقليد", "definition": "A custom or belief passed over time", "difficulty": "medium", "example": "It is a tradition to celebrate holidays."},
    {"text": "volunteer", "arabicMeaning": "متطوع", "definition": "To offer to do something without pay", "difficulty": "medium", "example": "He decided to volunteer at the hospital."},
    {"text": "adapt", "arabicMeaning": "يتكيف", "definition": "To change to fit a new situation", "difficulty": "medium", "example": "Animals must adapt to their environment."},
    {"text": "contribute", "arabicMeaning": "يساهم", "definition": "To give or help achieve something", "difficulty": "medium", "example": "Everyone should contribute to the team."},
    {"text": "demonstrate", "arabicMeaning": "يظهر", "definition": "To show how something works", "difficulty": "hard", "example": "The teacher will demonstrate the experiment."},
    {"text": "emphasize", "arabicMeaning": "يؤكد", "definition": "To give special importance to something", "difficulty": "hard", "example": "The report emphasizes the need for safety."},
]


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
    count = max(1, min(30, data.limit or 20))

    suggestions: list[dict] = []
    if settings.GEMINI_API_KEY:
        try:
            from app.services.ai_service import VocabGenAI

            ai = VocabGenAI(api_key=settings.GEMINI_API_KEY)
            result = ai.suggest_words_detailed(
                level=level,
                interests=interests,
                excluded_words=list(existing),
                count=count,
            )
            if isinstance(result, list):
                seen = set()
                for item in result:
                    text = (item.get("text") or "").strip().lower()
                    if text and text not in existing and text not in seen:
                        seen.add(text)
                        suggestions.append({
                            "text": item.get("text", "").strip(),
                            "arabicMeaning": item.get("arabicMeaning", ""),
                            "definition": item.get("definition", ""),
                            "difficulty": item.get("difficulty", "medium"),
                            "example": item.get("example", ""),
                            "level": level,
                        })
                if not suggestions:
                    logger.error("AI returned empty suggestion list; result=%s", str(result)[:200])
            elif isinstance(result, dict) and result.get("error"):
                logger.error("AI suggestions failed: %s", result.get("details") or result.get("error"))
        except Exception as exc:
            logger.exception("AI suggestions failed; using fallback")

    if not suggestions:
        logger.info("Using fallback suggestions for level=%s interests=%s", level, interests)
        service = TranslationService()
        for w in FALLBACK_WORDS:
            text_lower = w["text"].strip().lower()
            if text_lower not in existing and len(suggestions) < count:
                translation = service.translate(w["text"])
                suggestions.append({
                    "text": w["text"],
                    "arabicMeaning": translation.translation or w["arabicMeaning"],
                    "definition": w["definition"],
                    "difficulty": w["difficulty"],
                    "example": w["example"],
                    "level": level,
                })

    return suggestions[:count]
