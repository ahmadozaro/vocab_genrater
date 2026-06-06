from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.core.database import Base


class Question(Base):
    """Normal quiz item row.

    `correctAnswer` is retained for normal quiz compatibility only. SM2 quiz
    answers are stored separately in `sm2_quiz_items`.
    """

    __tablename__ = "normal_quiz_items"

    questionId = Column("id", Integer, primary_key=True, index=True)
    quizId = Column("attempt_id", Integer, ForeignKey("normal_quiz_attempts.id"), nullable=False)
    userWordId = Column("user_word_id", Integer, ForeignKey("user_words.id"), nullable=True)
    questionText = Column("question_text", Text, nullable=False)
    correctAnswer = Column("correct_answer", String, nullable=True)
    options = Column("options_json", Text, nullable=True)
    userAnswer = Column("user_answer", String, nullable=True)
    isCorrect = Column("is_correct", Boolean, nullable=True)
    questionType = Column("question_type", String, nullable=True, default="mcq")
    createdAt = Column("created_at", DateTime, default=datetime.utcnow, nullable=False)

    quiz = relationship("Quiz", back_populates="questions")
    user_word = relationship("Word", back_populates="quiz_items")
