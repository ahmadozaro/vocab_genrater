
from dataclasses import dataclass
from functools import lru_cache
 
 
@dataclass
class TranslationResult:
    translation: str | None
    provider: str
    error: str | None = None
 
 
_LOCAL_EN_AR: dict[str, str] = {
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
 
 
# ---------------------------------------------------------------------------
# Module-level cached translation — fixes the @lru_cache on instance method bug
# Using a module-level function avoids holding a reference to `self` in the
# cache, which would prevent garbage collection of TranslationService instances.
# ---------------------------------------------------------------------------
 
@lru_cache(maxsize=1000)
def _translate_cached(text: str, source: str, target: str) -> TranslationResult:
    """Perform the actual translation and cache the result at module level."""
    normalized = " ".join(text.lower().split())
 
    # 1. Local dict — instant, no network
    if normalized in _LOCAL_EN_AR:
        return TranslationResult(_LOCAL_EN_AR[normalized], "local")
 
    # 2. deep-translator (Google) — network call
    try:
        from deep_translator import GoogleTranslator
 
        translated = GoogleTranslator(source=source, target=target).translate(text)
        return TranslationResult(translated, "deep-translator")
    except Exception as exc:
        return TranslationResult(None, "fallback", str(exc))
 
 
class TranslationService:
    """Instant English-to-Arabic translation service.
 
    Uses a small local fallback first so the Add Word screen works during demos
    even if the internet / provider is unavailable. Then tries deep-translator.
 
    The underlying cache is module-level (not per-instance) so it is shared
    across all TranslationService instances and is not leaked by @lru_cache.
    """
 
    def __init__(self, source: str = "en", target: str = "ar") -> None:
        self.source = source
        self.target = target
 
    def translate(self, text: str) -> TranslationResult:
        clean = (text or "").strip()
        if not clean:
            return TranslationResult(None, "fallback", "empty text")
        return _translate_cached(clean, self.source, self.target)