from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.quiz_model import Quiz
from app.models.word_model import Word
from app.models.interest_model import user_interests


class User(Base):

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(String)
    email = Column(String, nullable=False, unique=True)
    password = Column("password_hash", String)
    reset_code = Column(String, nullable=True)
    email_verification_code = Column(String, nullable=True)
    is_email_verified = Column(Integer, default=0, nullable=False)
    login_otp_code = Column(String, nullable=True)
    login_otp_expires_at = Column(DateTime, nullable=True)
    login_otp_used = Column(Boolean, default=True, nullable=False)
    login_otp_attempts = Column(Integer, default=0, nullable=False)
    login_otp_resend_count = Column(Integer, default=0, nullable=False)
    login_otp_challenge_id = Column(String, nullable=True)
    login_otp_last_sent_at = Column(DateTime, nullable=True)

    level = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    words = relationship("Word", back_populates="owner")

    quizzes = relationship("Quiz", back_populates="owner")

    interests = relationship("Interest", secondary=user_interests, back_populates="users")

    progress = relationship("Progress", back_populates="owner", cascade="all, delete-orphan")

    notifications = relationship("Notification", back_populates="owner", cascade="all, delete-orphan")
