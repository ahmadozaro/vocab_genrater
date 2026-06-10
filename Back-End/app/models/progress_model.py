from sqlalchemy import Column, Date, DateTime, ForeignKey, Integer

from sqlalchemy.orm import relationship

from datetime import datetime

from app.core.database import Base





class Progress(Base):

    __tablename__ = "progress"



    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)

    daily_streak = Column(Integer, default=0, nullable=False)

    last_sm2_quiz_date = Column(Date, nullable=True)

    completed_sm2_quizzes = Column(Integer, default=0, nullable=False)

    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)



    owner = relationship("User", back_populates="progress")

