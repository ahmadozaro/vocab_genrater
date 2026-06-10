from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from sqlalchemy.orm import relationship

from datetime import datetime

from app.core.database import Base





class Notification(Base):

    __tablename__ = "notifications"



    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    title = Column(String, nullable=False, default="Notification")

    message = Column(String, nullable=False)

    type = Column(String, nullable=True)

    is_read = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)



    owner = relationship("User", back_populates="notifications")

