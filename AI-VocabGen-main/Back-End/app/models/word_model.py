from datetime import datetime

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class DictionaryWord(Base):
    """Global word data stored once for all users."""

    __tablename__ = "dictionary_words"

    id = Column(Integer, primary_key=True, index=True)
    text = Column(String, nullable=False)
    normalized_text = Column(String, nullable=False, unique=True, index=True)
    definition_en = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    translations = relationship("WordTranslation", back_populates="word", cascade="all, delete-orphan")
    examples = relationship("WordExample", back_populates="word", cascade="all, delete-orphan")
    user_words = relationship("Word", back_populates="dictionary_word")


class WordTranslation(Base):
    """Arabic translation for a dictionary word."""

    __tablename__ = "word_translations"
    __table_args__ = (UniqueConstraint("word_id", "provider", name="uq_word_translation_provider"),)

    id = Column(Integer, primary_key=True, index=True)
    word_id = Column(Integer, ForeignKey("dictionary_words.id"), nullable=False)
    translation_text = Column(String, nullable=False)
    provider = Column(String, default="translation_service", nullable=False)
    is_primary = Column(Integer, default=1, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    word = relationship("DictionaryWord", back_populates="translations")


class WordExample(Base):
    """Example sentence for a dictionary word."""

    __tablename__ = "word_examples"

    id = Column(Integer, primary_key=True, index=True)
    word_id = Column(Integer, ForeignKey("dictionary_words.id"), nullable=False)
    sentence_en = Column(Text, nullable=False)
    sentence_ar = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    word = relationship("DictionaryWord", back_populates="examples")


class Word(Base):
    """User-specific learning and SM2 state for a dictionary word."""

    __tablename__ = "user_words"
    __table_args__ = (UniqueConstraint("user_id", "word_id", name="uq_user_word"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    word_id = Column(Integer, ForeignKey("dictionary_words.id"), nullable=False)
    status = Column(String, default="new", nullable=False)
    activation_date = Column(DateTime, nullable=True)
    added_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    score = Column(Integer, default=0, nullable=False)
    sm2_repeats = Column(Integer, default=0, nullable=False)
    sm2_ease_factor = Column(Float, default=2.5, nullable=False)
    sm2_interval_days = Column(Integer, default=0, nullable=False)
    next_review_at = Column(DateTime, nullable=True)
    last_reviewed_at = Column(DateTime, nullable=True)
    correct_streak = Column(Integer, default=0, nullable=False)
    wrong_streak = Column(Integer, default=0, nullable=False)

    owner = relationship("User", back_populates="words")
    dictionary_word = relationship("DictionaryWord", back_populates="user_words")
    quiz_items = relationship("Question", back_populates="user_word")
    sm2_items = relationship("SM2QuizItem", back_populates="user_word")

    @property
    def wordId(self) -> int:
        return self.id

    @property
    def userId(self) -> int:
        return self.user_id

    @property
    def text(self) -> str:
        return self.dictionary_word.text if self.dictionary_word else ""

    @property
    def normalizedText(self) -> str | None:
        return self.dictionary_word.normalized_text if self.dictionary_word else None

    @property
    def definition(self) -> str | None:
        return self.dictionary_word.definition_en if self.dictionary_word else None

    @property
    def sm2Repeats(self) -> int:
        return self.sm2_repeats

    @sm2Repeats.setter
    def sm2Repeats(self, value: int) -> None:
        self.sm2_repeats = value

    @property
    def sm2EaseFactor(self) -> float:
        return self.sm2_ease_factor

    @sm2EaseFactor.setter
    def sm2EaseFactor(self, value: float) -> None:
        self.sm2_ease_factor = value

    @property
    def sm2IntervalDays(self) -> int:
        return self.sm2_interval_days

    @sm2IntervalDays.setter
    def sm2IntervalDays(self, value: int) -> None:
        self.sm2_interval_days = value

    @property
    def nextReviewDate(self):
        return self.next_review_at

    @nextReviewDate.setter
    def nextReviewDate(self, value) -> None:
        self.next_review_at = value

    @property
    def lastReviewedAt(self):
        return self.last_reviewed_at

    @lastReviewedAt.setter
    def lastReviewedAt(self, value) -> None:
        self.last_reviewed_at = value

    @property
    def correctStreak(self) -> int:
        return self.correct_streak

    @correctStreak.setter
    def correctStreak(self, value: int) -> None:
        self.correct_streak = value

    @property
    def wrongStreak(self) -> int:
        return self.wrong_streak

    @wrongStreak.setter
    def wrongStreak(self, value: int) -> None:
        self.wrong_streak = value

    @property
    def translationAr(self) -> str | None:
        if not self.dictionary_word:
            return None
        primary = next((t for t in self.dictionary_word.translations if t.is_primary), None)
        translation = primary or (self.dictionary_word.translations[0] if self.dictionary_word.translations else None)
        return translation.translation_text if translation else None

    @property
    def arabicMeaning(self) -> str | None:
        return self.translationAr

    @property
    def translationProvider(self) -> str | None:
        if not self.dictionary_word:
            return None
        primary = next((t for t in self.dictionary_word.translations if t.is_primary), None)
        translation = primary or (self.dictionary_word.translations[0] if self.dictionary_word.translations else None)
        return translation.provider if translation else None

    @property
    def sentences(self) -> list[WordExample]:
        return self.dictionary_word.examples if self.dictionary_word else []
