import logging

from typing import List



from fastapi import APIRouter, Depends

from pydantic import BaseModel



from app.auth import get_current_user

from app.core.config import settings

from app.models.user_model import User

from app.services.ai_service import VocabGenAI



router = APIRouter(prefix="/ai", tags=["AI"])

logger = logging.getLogger(__name__)





class SuggestWordsRequest(BaseModel):

    level: str = "B1"

    interests: List[str] = []

    existingWords: List[str] = []

    limit: int = 20





def _get_ai() -> VocabGenAI | None:

    if not settings.GROQ_API_KEY:

        return None

    return VocabGenAI(api_key=settings.GROQ_API_KEY, model=settings.GROQ_MODEL)





@router.get("/health")

def ai_health():

    configured = bool(settings.GROQ_API_KEY)

    if not configured:

        return {

            "provider": "groq",

            "configured": False,

            "model": settings.GROQ_MODEL,

            "ok": False,

            "message": "GROQ_API_KEY is not configured",

        }

    try:

        ai = _get_ai()

        health = ai.health_check()

        return {

            "provider": "groq",

            "configured": True,

            "model": settings.GROQ_MODEL,

            "ok": health.get("ok", False),

            "message": "AI provider is healthy" if health.get("ok") else "AI provider health check failed",

        }

    except Exception as exc:

        logger.exception("AI health check failed")

        return {

            "provider": "groq",

            "configured": True,

            "model": settings.GROQ_MODEL,

            "ok": False,

            "message": f"AI health check error: {str(exc)[:100]}",

        }





@router.post("/suggest-words")

def suggest_words(

    data: SuggestWordsRequest,

    current_user: User = Depends(get_current_user),

):

    existing = {w.strip().lower() for w in data.existingWords if w.strip()}

    level = data.level or current_user.level or "B1"

    interests = data.interests or ["general vocabulary"]

    count = max(1, min(30, data.limit or 20))



    ai = _get_ai()

    if ai:

        try:

            result = ai.suggest_words_detailed(

                level=level,

                interests=interests,

                excluded_words=list(existing),

                count=count,

            )

            if isinstance(result, list) and result:

                return result[:count]

        except Exception as exc:

            logger.error("AI suggestions failed: %.200s", str(exc))



    logger.info("Using fallback suggestions for level=%s interests=%s", level, interests)

    return VocabGenAI._fallback_suggestions(level, list(existing), count)[:count]

