from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.database import Base


class Quiz(Base):
    """Normal/practice/AI quiz attempt.

    This maps the legacy `Quiz` class to the redesigned `normal_quiz_attempts`
    table. Normal quizzes never update SM2 scheduling.
    """

    __tablename__ = "normal_quiz_attempts"

    quizId = Column("id", Integer, primary_key=True, index=True)
    userId = Column("user_id", Integer, ForeignKey("users.id"), nullable=False)
    quizType = Column("quiz_type", String, default="recent", nullable=False)
    score = Column(Integer, nullable=True)
    questionsCount = Column("total_questions", Integer, default=0, nullable=False)
    date = Column("started_at", DateTime, default=datetime.utcnow, nullable=False)
    submittedAt = Column("submitted_at", DateTime, nullable=True)
    status = Column(String, default="in_progress", nullable=False)

    owner = relationship("User", back_populates="quizzes")
    questions = relationship("Question", back_populates="quiz", cascade="all, delete-orphan")

    @property
    def wordList(self) -> None:
        return None
