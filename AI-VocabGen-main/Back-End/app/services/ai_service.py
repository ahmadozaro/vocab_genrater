import json
import logging
from typing import Any

from google import genai

from app.core.config import settings


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VocabGenAI:
    """AI engine for AI VocabGen using the current Google GenAI SDK."""

    SYSTEM_INSTRUCTION = (
        "You are an expert English Language Professor and AI Tutor. "
        "Your goal is to help students learn vocabulary effectively. "
        "Rules: "
        "1. Context is King: Never provide words in isolation; always use natural, modern English. "
        "2. Level Accuracy: Strictly follow CEFR levels (A1 to C2). If a user is B1, don't use C1 vocabulary in explanations. "
        "3. Diversity: Ensure variety in word selection and example contexts (tech, daily life, work, nature). "
        "4. Output Format: You MUST always respond in valid JSON format ONLY. Do not use markdown blocks outside the JSON. "
        "5. Arabic Support: Translations must be natural Modern Standard Arabic, not literal or robotic."
    )

    def __init__(self, api_key: str, model: str | None = None):
        if not api_key:
            raise ValueError("GEMINI_API_KEY is not configured")
        self.client = genai.Client(api_key=api_key)
        self.model_name = model or settings.GEMINI_MODEL
        logger.info("AI Engine initialized with model %s.", self.model_name)

    def _extract_text(self, response: Any) -> str:
        text = getattr(response, "text", None)
        if text:
            return text
        try:
            return response.candidates[0].content.parts[0].text
        except Exception:
            try:
                return response.candidates[0].content.parts[0].model_dump().get("text", "")
            except Exception:
                return str(response)

    def _generate_content_smart(self, prompt: str):
        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt,
                config={
                    "system_instruction": self.SYSTEM_INSTRUCTION,
                    "temperature": 0.7,
                    "top_p": 0.95,
                    "response_mime_type": "application/json",
                },
            )
            raw_text = (self._extract_text(response) or "").strip()
            if not raw_text:
                logger.error("AI returned an empty response for prompt: %s", prompt)
                return {"error": "AI returned an empty response", "details": "No text content was found."}

            try:
                return json.loads(raw_text)
            except json.JSONDecodeError as exc:
                logger.error("AI returned invalid JSON. raw_response=%s", raw_text[:500])
                return {
                    "error": "AI returned invalid JSON",
                    "details": str(exc),
                    "raw_response": raw_text[:500],
                }
        except Exception as exc:
            logger.exception("AI generation failed")
            return {"error": "Failed to generate AI content", "details": str(exc)}

    def health_check(self) -> dict:
        prompt = 'Return ONLY this JSON object: {"ok": true}'
        result = self._generate_content_smart(prompt)
        if isinstance(result, dict) and result.get("ok") is True:
            return {"ok": True}
        if isinstance(result, dict) and result.get("error"):
            return {"ok": False, "error": result.get("details") or result.get("error")}
        return {"ok": False, "error": "Unexpected AI health response"}

    def suggest_smart_words(self, level: str, interests: list, excluded_words: list = None):
        prompt = f"""
        Task: Suggest 5 unique English vocabulary words for a learner at {level} level.
        Interests: {', '.join(interests)}.
        Excluded Words (Do NOT suggest these): {excluded_words or []}.

        Output Requirement:
        Return ONLY a JSON array of strings containing the suggested words.
        Do not include any keys, explanations, or markdown formatting.

        Example exact format:
        ["word1", "word2", "word3", "word4", "word5"]
        """
        return self._generate_content_smart(prompt)

    def get_contextual_details(self, word: str, level: str):
        prompt = f"""
        Task: Provide deep insights for the word "{word}" for level {level}.
        Requirement: The example sentence must be self-explanatory.

        Return JSON exactly like this:
        {{
            "word": "{word}",
            "phonetic": "simple pronunciation guide",
            "arabic_meaning": "natural Arabic translation",
            "english_definition": "simple English definition suitable for {level} level",
            "context_sentence": "the self-explanatory example sentence",
            "arabic_context_translation": "natural Arabic translation of the sentence",
            "synonyms": ["synonym1", "synonym2"],
            "common_mistake": "a very short note on a common error learners make with this word"
        }}
        """
        return self._generate_content_smart(prompt)

    def generate_adaptive_quiz(self, words_with_levels: list):
        prompt = f"""
        Task: Create a 5-question multiple-choice quiz (MCQ) testing these specific words: {words_with_levels}.

        Logic for Questions:
        - Make 3 questions "Fill in the blank" context sentences.
        - Make 2 questions "Synonym or Antonym" matching.
        - The wrong options must be realistic and appropriate for the words' levels.

        Return JSON exactly like this:
        {{
            "questions": [
                {{
                    "question_text": "The sentence with a blank or the direct question",
                    "options": ["Option A", "Option B", "Option C", "Option D"],
                    "correct_answer": "The exact string of the correct option",
                    "tested_word": "The original word being tested here",
                    "explanation": "Short explanation of why this is the correct answer"
                }}
            ]
        }}
        """
        return self._generate_content_smart(prompt)

    def generate_review_quiz(self, words: list, level: str = "A1"):
        prompt = f"""
        Task: Create a multiple-choice review quiz for an English learner at {level} level.
        Use these saved vocabulary words and meanings: {words}.

        Rules:
        - Generate between 1 and 10 questions.
        - Each question must be multiple choice.
        - Each question must have exactly 4 options.
        - The correct_answer must exactly match one of the 4 options.
        - Keep language appropriate for CEFR level {level}.

        Return JSON exactly like this:
        {{
            "questions": [
                {{
                    "question_text": "Question text",
                    "options": ["Option A", "Option B", "Option C", "Option D"],
                    "correct_answer": "Option A"
                }}
            ]
        }}
        """
        return self._generate_content_smart(prompt)
