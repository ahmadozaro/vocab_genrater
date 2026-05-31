from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.database import Base


class SM2Quiz(Base):
    __tablename__ = "sm2_quiz_attempts"

    id = Column(Integer, primary_key=True, index=True)
    userId = Column("user_id", Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, nullable=True)
    questionsCount = Column("total_questions", Integer, default=0, nullable=False)
    startedAt = Column("started_at", DateTime, default=datetime.utcnow, nullable=False)
    submittedAt = Column("submitted_at", DateTime, nullable=True)
    status = Column(String, default="in_progress", nullable=False)
    countsForStreak = Column("counts_for_streak", Boolean, default=False, nullable=False)

    items = relationship("SM2QuizItem", back_populates="quiz", cascade="all, delete-orphan")


class SM2QuizItem(Base):
    __tablename__ = "sm2_quiz_items"

    id = Column(Integer, primary_key=True, index=True)
    quizId = Column("attempt_id", Integer, ForeignKey("sm2_quiz_attempts.id"), nullable=False)
    userWordId = Column("user_word_id", Integer, ForeignKey("user_words.id"), nullable=False)
    questionText = Column("question_text", Text, nullable=False)
    questionType = Column("question_type", String, default="meaning_to_word", nullable=False)
    correctAnswer = Column("correct_answer", String, nullable=False)
    options = Column("options_json", Text, nullable=True)
    userAnswer = Column("user_answer", String, nullable=True)
    isCorrect = Column("is_correct", Boolean, nullable=True)
    durationSeconds = Column("duration_seconds", Integer, nullable=True)
    quality = Column(Integer, nullable=True)
    createdAt = Column("created_at", DateTime, default=datetime.utcnow, nullable=False)

    quiz = relationship("SM2Quiz", back_populates="items")
    user_word = relationship("Word", back_populates="sm2_items")

    @property
    def wordId(self) -> int:
        return self.userWordId
