"""
Shared quiz utilities used by both quiz_router and sm2_quiz_router.
Eliminates duplicated question-generation logic and helper functions.
"""
import random
from datetime import datetime
from typing import TYPE_CHECKING
 
from sqlalchemy.orm import Session
 
from app.models.progress_model import Progress
 
if TYPE_CHECKING:
    from app.models.word_model import Word
 
 
# ---------------------------------------------------------------------------
# Answer normalisation (single source of truth)
# ---------------------------------------------------------------------------
 
def normalize_answer(value: str | None) -> str:
    """Strip, lowercase, and collapse internal whitespace."""
    return " ".join((value or "").strip().lower().split())
 
 
# ---------------------------------------------------------------------------
# Progress helper (was duplicated in progress_router & sm2_quiz_router)
# ---------------------------------------------------------------------------
 
def get_or_create_progress(db: Session, user_id: int) -> Progress:
    """Return the Progress row for *user_id*, creating it if absent."""
    progress = db.query(Progress).filter(Progress.user_id == user_id).first()
    if progress:
        return progress
    progress = Progress(user_id=user_id)
    db.add(progress)
    db.flush()
    return progress
 
 
# ---------------------------------------------------------------------------
# Grade helper
# ---------------------------------------------------------------------------
 
def grade_for(percentage: float) -> str:
    if percentage >= 90:
        return "Excellent"
    if percentage >= 70:
        return "Good"
    if percentage >= 50:
        return "Average"
    return "Needs Work"
 
 
# ---------------------------------------------------------------------------
# Question generators (was duplicated in quiz_router & sm2_quiz_router)
# ---------------------------------------------------------------------------
 
def _word_prompt_text(word: "Word") -> str:
    definition = (word.definition or "").strip()
    sentence = ""
    if word.sentences:
        sentence = word.sentences[0].sentence_en.strip() if word.sentences[0].sentence_en else ""

    if sentence and word.text in sentence:
        masked = sentence.replace(word.text, "_____")
        return f'Which English word best completes this sentence: "{masked}"?'
    if sentence:
        return f'Which English word best fits this sentence: "{sentence}"?'
    if definition:
        return f'Which English word matches this definition: "{definition}"?'
    return f'Which English word is described here?'


def generate_mcq(
    word: "Word",
    all_words: list["Word"],
) -> tuple[str, list[str], str]:
    """Multiple-choice: choose the correct English word from four options."""
    correct = word.text
    all_texts = [w.text for w in all_words if w.text and w.text != correct]
    distractors = random.sample(all_texts, min(3, len(all_texts)))
    while len(distractors) < 3:
        distractors.append(f"option{len(distractors)}")
    options = distractors + [correct]
    random.shuffle(options)
    question_text = _word_prompt_text(word)
    return question_text, options, correct
 
 
def generate_true_false(
    word: "Word",
    all_texts: list[str],
) -> tuple[str, list[str], str]:
    """True/False: decide whether this English word matches a definition or sentence."""
    correct = word.text
    definition = (word.definition or "").strip()
    sentence = ""
    if word.sentences:
        sentence = word.sentences[0].sentence_en.strip() if word.sentences[0].sentence_en else ""
    is_true = random.choice([True, False])
    if definition:
        if is_true:
            statement = f'Is it true that "{correct}" means "{definition}"?'
        else:
            others = [t for t in all_texts if t != correct]
            other = random.choice(others) if others else "another word"
            statement = f'Is it true that "{other}" means "{definition}"?'
    elif sentence:
        if is_true:
            statement = f'Does the sentence "{sentence}" correctly use the word "{correct}"?'
        else:
            others = [t for t in all_texts if t != correct]
            other = random.choice(others) if others else "another word"
            statement = f'Does the sentence "{sentence}" correctly use the word "{other}"?'
    else:
        if is_true:
            statement = f'Is it true that "{correct}" is the right English word for this idea?'
        else:
            others = [t for t in all_texts if t != correct]
            other = random.choice(others) if others else "another word"
            statement = f'Is it true that "{other}" is the right English word for this idea?'
    return statement, ["True", "False"], "True" if is_true else "False"
 
 
# ---------------------------------------------------------------------------
# Batch builder used by quiz_router
# ---------------------------------------------------------------------------
 
QUESTION_TYPES = ["mcq", "tf"]
 
 
def build_question_rows(
    all_words: list["Word"],
    selected: list["Word"],
) -> list[tuple["Word", str, list[str], str, str]]:
    """
    Return a list of (word, question_text, options, correct_answer, qtype)
    alternating MCQ and True/False.
    """
    all_texts = [w.text for w in all_words if w.text]
    rows: list[tuple["Word", str, list[str], str, str]] = []
    for i, word in enumerate(selected):
        r = i % len(QUESTION_TYPES)
        if r == 1:
            q_text, opts, correct = generate_true_false(word, all_texts)
            qtype = "tf"
        else:
            q_text, opts, correct = generate_mcq(word, all_words)
            qtype = "mcq"
        rows.append((word, q_text, opts, correct, qtype))
    return rows