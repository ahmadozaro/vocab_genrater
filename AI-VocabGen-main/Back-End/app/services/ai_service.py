import json
import logging
import random

import httpx

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

logger = logging.getLogger(__name__)

_FALLBACK_WORDS = [
    {"text": "improve", "arabicMeaning": "يحسن", "definition": "To make something better", "difficulty": "easy", "example": "I want to improve my English.", "level": "A2"},
    {"text": "focus", "arabicMeaning": "يركز", "definition": "To give full attention to something", "difficulty": "easy", "example": "Please focus on your work.", "level": "A2"},
    {"text": "review", "arabicMeaning": "يراجع", "definition": "To look at something again", "difficulty": "easy", "example": "Let me review this chapter.", "level": "A2"},
    {"text": "practice", "arabicMeaning": "ممارسة", "definition": "To do something many times to get better", "difficulty": "easy", "example": "Practice makes perfect.", "level": "A2"},
    {"text": "achieve", "arabicMeaning": "يحقق", "definition": "To successfully reach a goal", "difficulty": "medium", "example": "She worked hard to achieve her dream.", "level": "B1"},
    {"text": "benefit", "arabicMeaning": "فائدة", "definition": "An advantage or positive result", "difficulty": "medium", "example": "Exercise has many health benefits.", "level": "B1"},
    {"text": "challenge", "arabicMeaning": "تحدي", "definition": "Something difficult that tests your ability", "difficulty": "medium", "example": "Learning a new language is a big challenge.", "level": "B1"},
    {"text": "discover", "arabicMeaning": "يكتشف", "definition": "To find something for the first time", "difficulty": "medium", "example": "Scientists discover new things every day.", "level": "B1"},
    {"text": "establish", "arabicMeaning": "يؤسس", "definition": "To start or create something", "difficulty": "hard", "example": "The company was established in 2010.", "level": "B2"},
    {"text": "frequent", "arabicMeaning": "متكرر", "definition": "Happening often", "difficulty": "medium", "example": "She makes frequent trips to the library.", "level": "B1"},
    {"text": "generate", "arabicMeaning": "يولد", "definition": "To produce or create something", "difficulty": "medium", "example": "The wind turbines generate electricity.", "level": "B1"},
    {"text": "identify", "arabicMeaning": "يحدد", "definition": "To recognize and name something", "difficulty": "medium", "example": "Can you identify the problem?", "level": "B1"},
    {"text": "maintain", "arabicMeaning": "يحافظ", "definition": "To keep something in good condition", "difficulty": "medium", "example": "It is important to maintain your health.", "level": "B1"},
    {"text": "negotiate", "arabicMeaning": "يتفاوض", "definition": "To discuss to reach an agreement", "difficulty": "hard", "example": "They need to negotiate a new contract.", "level": "B2"},
    {"text": "obtain", "arabicMeaning": "يحصل على", "definition": "To get or acquire something", "difficulty": "medium", "example": "You need to obtain permission first.", "level": "B1"},
    {"text": "persuade", "arabicMeaning": "يقنع", "definition": "To make someone believe or do something", "difficulty": "hard", "example": "She persuaded him to join the team.", "level": "B2"},
    {"text": "require", "arabicMeaning": "يتطلب", "definition": "To need something", "difficulty": "medium", "example": "This job requires experience.", "level": "B1"},
    {"text": "significant", "arabicMeaning": "مهم", "definition": "Important or large enough to notice", "difficulty": "medium", "example": "There was a significant increase in sales.", "level": "B1"},
    {"text": "tradition", "arabicMeaning": "تقليد", "definition": "A custom or belief passed over time", "difficulty": "medium", "example": "It is a tradition to celebrate holidays.", "level": "B1"},
    {"text": "volunteer", "arabicMeaning": "متطوع", "definition": "To offer to do something without pay", "difficulty": "medium", "example": "He decided to volunteer at the hospital.", "level": "B1"},
    {"text": "adapt", "arabicMeaning": "يتكيف", "definition": "To change to fit a new situation", "difficulty": "medium", "example": "Animals must adapt to their environment.", "level": "B1"},
    {"text": "contribute", "arabicMeaning": "يساهم", "definition": "To give or help achieve something", "difficulty": "medium", "example": "Everyone should contribute to the team.", "level": "B1"},
    {"text": "demonstrate", "arabicMeaning": "يظهر", "definition": "To show how something works", "difficulty": "hard", "example": "The teacher will demonstrate the experiment.", "level": "B2"},
    {"text": "emphasize", "arabicMeaning": "يؤكد", "definition": "To give special importance to something", "difficulty": "hard", "example": "The report emphasizes the need for safety.", "level": "B2"},
]


def _strip_markdown_fences(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith("```"):
        lines = raw.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        raw = "\n".join(lines).strip()
    return raw


class VocabGenAI:

    SYSTEM_PROMPT = (
        "You are an expert English Language Professor and AI Tutor. "
        "Your goal is to help students learn vocabulary effectively. "
        "Rules: "
        "1. Context is King: Never provide words in isolation; always use natural, modern English. "
        "2. Level Accuracy: Strictly follow CEFR levels (A1 to C2). "
        "3. Diversity: Ensure variety in word selection and example contexts. "
        "4. Output Format: You MUST always respond in valid JSON format ONLY. No markdown fences. "
        "5. Arabic Support: Translations must be natural Modern Standard Arabic."
    )

    def __init__(self, api_key: str, model: str):
        self.api_key = api_key
        self.model = model
        self._client = httpx.Client(timeout=30.0)

    def _call_groq(self, user_prompt: str) -> dict | None:
        try:
            resp = self._client.post(
                GROQ_API_URL,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": self.SYSTEM_PROMPT},
                        {"role": "user", "content": user_prompt},
                    ],
                    "temperature": 0.7,
                    "max_tokens": 4096,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            raw = data["choices"][0]["message"]["content"]
            raw = _strip_markdown_fences(raw)
            return json.loads(raw)
        except httpx.HTTPStatusError as e:
            logger.error("Groq API error (status %s): %.200s", e.response.status_code, str(e))
        except json.JSONDecodeError as e:
            logger.error("Groq JSON error: %.200s", str(e))
        except Exception as e:
            logger.error("Groq call failed: %.200s", str(e))
        return None

    def health_check(self) -> dict:
        result = self._call_groq('Return ONLY valid JSON: {"ok": true}')
        if isinstance(result, dict) and result.get("ok") is True:
            return {"ok": True}
        return {"ok": False, "error": "AI provider health check failed"}

    def generate_word_details(self, word: str, level: str = "B1") -> dict:
        prompt = f"""Return ONLY valid JSON for the word "{word}" at CEFR level {level}.
{{
  "definition_en": "simple English definition appropriate for {level}",
  "example_sentence_en": "A natural sentence using the word {word}",
  "example_sentence_ar": "Arabic translation of the example sentence",
  "contextual_meaning_ar": "optional Arabic contextual explanation"
}}"""
        result = self._call_groq(prompt)
        if isinstance(result, dict) and result.get("definition_en"):
            return result
        return {
            "definition_en": f"A vocabulary word: {word}.",
            "example_sentence_en": f"I learned the word {word} today.",
            "example_sentence_ar": "",
            "contextual_meaning_ar": "",
        }

    def suggest_words_detailed(
        self,
        level: str = "B1",
        interests: list[str] | None = None,
        excluded_words: list[str] | None = None,
        count: int = 20,
    ) -> list[dict]:
        excluded = excluded_words or []
        interests_str = ", ".join(interests or ["general vocabulary"])
        prompt = f"""Suggest {count} unique English vocabulary words for CEFR level {level}.
Interests: {interests_str}.
Excluded words (DO NOT include): {excluded}.

Return ONLY a JSON array of exactly {count} objects. Each object:
- "text": the English word
- "arabicMeaning": natural Arabic translation
- "definition": simple English definition for {level}
- "difficulty": "easy", "medium", or "hard"
- "example": simple example sentence
- "level": "{level}"

No duplicates. No excluded words. Cover diverse contexts."""
        result = self._call_groq(prompt)
        if isinstance(result, list) and len(result) > 0:
            seen = set()
            cleaned = []
            for item in result:
                text = (item.get("text") or "").strip().lower()
                if text and text not in seen and text not in {w.lower() for w in excluded}:
                    seen.add(text)
                    cleaned.append({
                        "text": item.get("text", "").strip(),
                        "arabicMeaning": item.get("arabicMeaning", ""),
                        "definition": item.get("definition", ""),
                        "difficulty": item.get("difficulty", "medium"),
                        "example": item.get("example", ""),
                        "level": level,
                    })
            if cleaned:
                return cleaned
        return self._fallback_suggestions(level, excluded_words, count)

    @staticmethod
    def _fallback_suggestions(level: str, excluded: list[str] | None, count: int) -> list[dict]:
        excluded_set = {w.lower() for w in (excluded or [])}
        result = []
        for w in _FALLBACK_WORDS:
            if w["text"].lower() not in excluded_set:
                result.append({**w, "level": level})
                if len(result) >= count:
                    break
        if len(result) < count:
            backup = ["gather", "mention", "proceed", "recognize", "separate",
                      "transform", "encounter", "engage", "establish", "evaluate"]
            for text in backup:
                if len(result) >= count:
                    break
                if text.lower() not in excluded_set and text.lower() not in {w["text"].lower() for w in result}:
                    result.append({
                        "text": text,
                        "arabicMeaning": "",
                        "definition": f"A vocabulary word: {text}.",
                        "difficulty": "medium",
                        "example": f"I learned the word {text} today.",
                        "level": level,
                    })
        return result

    def generate_quiz_questions(self, words: list[dict], count: int = 5) -> list[dict]:
        words_str = "; ".join(f"{w.get('text', '?')} ({w.get('arabicMeaning', '?')})" for w in words)
        prompt = f"""Create {count} multiple-choice quiz questions for these vocabulary words:
{words_str}

Return ONLY a JSON array of exactly {count} objects:
- "questionText": the question
- "options": array of exactly 4 strings
- "correctAnswer": one of the 4 options (exact match)
- "questionType": "multiple_choice"

Mix fill-in-the-blank and meaning questions. Keep language simple."""
        result = self._call_groq(prompt)
        if isinstance(result, list) and len(result) > 0:
            valid = []
            for q in result:
                if q.get("questionText") and isinstance(q.get("options"), list) and len(q["options"]) == 4 and q.get("correctAnswer") in q["options"]:
                    valid.append({
                        "questionText": q["questionText"],
                        "options": [str(o) for o in q["options"]],
                        "correctAnswer": str(q["correctAnswer"]),
                        "wordId": None,
                        "questionType": "multiple_choice",
                    })
            if valid:
                return valid
        return self._fallback_quiz_questions(words, count)

    @staticmethod
    def _fallback_quiz_questions(words: list[dict], count: int) -> list[dict]:
        selected = random.sample(words, min(count, len(words)))
        questions = []
        for w in selected:
            text = w.get("text", "")
            meaning = w.get("arabicMeaning", "")
            others = [x.get("text", "") for x in words if x.get("text", "").lower() != text.lower()]
            distractors = random.sample(others, min(3, len(others))) if len(others) >= 3 else (others * 3)[:3]
            while len(distractors) < 3:
                distractors.append(f"word{len(distractors)}")
            options = distractors + [text]
            random.shuffle(options)
            question_text = f"What is the English word for: {meaning}?" if meaning else f"What word means: {text}?"
            if meaning and random.choice([True, False]):
                question_text = f'Fill in the blank: "The _____ means {meaning}."'
            questions.append({
                "questionText": question_text,
                "options": options,
                "correctAnswer": text,
                "wordId": w.get("wordId"),
                "questionType": "multiple_choice",
            })
        return questions
