from dataclasses import dataclass
from functools import lru_cache


@dataclass
class TranslationResult:
    translation: str | None
    provider: str
    error: str | None = None


_LOCAL_EN_AR = {
    "man": "رجل",
    "woman": "امرأة",
    "book": "كتاب",
    "student": "طالب",
    "teacher": "معلم",
    "school": "مدرسة",
    "work": "عمل",
    "learn": "يتعلم",
    "improve": "يحسن",
    "practice": "ممارسة",
    "memory": "ذاكرة",
    "review": "مراجعة",
    "example": "مثال",
    "word": "كلمة",
    "language": "لغة",
}


class TranslationService:
    """Instant English-to-Arabic translation service.

    Uses a small local fallback first so the Add Word screen works during demos
    even if the internet/provider is unavailable. Then tries deep-translator.
    """

    def __init__(self, source: str = "en", target: str = "ar"):
        self.source = source
        self.target = target

    @lru_cache(maxsize=1000)
    def translate(self, text: str) -> TranslationResult:
        clean = (text or "").strip()
        normalized = " ".join(clean.lower().split())
        if not normalized:
            return TranslationResult(None, "fallback", "empty text")

        if normalized in _LOCAL_EN_AR:
            return TranslationResult(_LOCAL_EN_AR[normalized], "local")

        try:
            from deep_translator import GoogleTranslator

            translated = GoogleTranslator(source=self.source, target=self.target).translate(clean)
            return TranslationResult(translated, "deep-translator")
        except Exception as exc:
            return TranslationResult(None, "fallback", str(exc))
