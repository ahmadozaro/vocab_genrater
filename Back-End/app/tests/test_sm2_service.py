from datetime import datetime
from types import SimpleNamespace
from unittest import TestCase

from app.services.sm2_service import apply_modified_sm2


class FakeWord(SimpleNamespace):
    pass


def make_word(**overrides):
    values = {
        "score": 0,
        "sm2Repeats": 0,
        "sm2EaseFactor": 2.5,
        "sm2IntervalDays": 0,
        "nextReviewDate": None,
        "lastReviewedAt": None,
        "correctStreak": 0,
        "wrongStreak": 0,
        "status": "new",
    }
    values.update(overrides)
    return FakeWord(**values)


class SM2ServiceTest(TestCase):
    def test_fast_correct_boosts_ease_interval_and_flags_perfect_answer(self):
        word = make_word(sm2EaseFactor=2.75, sm2Repeats=2, sm2IntervalDays=5, score=40)

        snapshot = apply_modified_sm2(
            word,
            5,
            reviewed_at=datetime(2026, 6, 7),
            is_correct=True,
            question_type="mcq",
            user_answer="focus",
        )

        self.assertEqual(snapshot.new_ease_factor, 2.8)
        self.assertEqual(snapshot.new_interval_days, 10)
        self.assertEqual(snapshot.score_delta, 10)
        self.assertEqual(snapshot.error_type, "none")
        self.assertIn("perfect_answer", snapshot.achievement_flags)

    def test_repeated_wrong_marks_hard_and_recommends_focus_review(self):
        word = make_word(sm2Repeats=3, wrongStreak=2, status="review", score=50)

        snapshot = apply_modified_sm2(
            word,
            1,
            reviewed_at=datetime(2026, 6, 7),
            is_correct=False,
            question_type="mcq",
            user_answer="practice",
        )

        self.assertEqual(snapshot.status, "hard")
        self.assertEqual(snapshot.smart_action, "focus_review")
        self.assertEqual(snapshot.error_type, "confusion_with_similar_words")
        self.assertEqual(snapshot.new_interval_days, 1)
        self.assertEqual(snapshot.next_review_label, "today")

    def test_mastered_word_recommends_boost_interval_and_sets_flag(self):
        word = make_word(
            sm2Repeats=4,
            sm2IntervalDays=21,
            sm2EaseFactor=2.5,
            correctStreak=4,
            score=84,
            status="review",
        )

        snapshot = apply_modified_sm2(
            word,
            5,
            reviewed_at=datetime(2026, 6, 7),
            is_correct=True,
            question_type="fill",
            user_answer="focus",
        )

        self.assertEqual(snapshot.status, "mastered")
        self.assertEqual(snapshot.smart_action, "boost_interval")
        self.assertIn("word_mastered", snapshot.achievement_flags)
        self.assertIn("5_correct_streak", snapshot.achievement_flags)
