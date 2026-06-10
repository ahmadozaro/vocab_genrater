from sqlalchemy import Column, Integer, String, DateTime, Table, ForeignKey

from sqlalchemy.orm import relationship

from datetime import datetime

from app.core.database import Base





user_interests = Table('user_interests', Base.metadata,

    Column('user_id', Integer, ForeignKey('users.id'), primary_key=True),

    Column('interest_id', Integer, ForeignKey('interests.id'), primary_key=True)

)





class Interest(Base):

    __tablename__ = "interests"



    id = Column(Integer, primary_key=True, index=True)

    name = Column(String, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)



    users = relationship("User", secondary=user_interests, back_populates="interests")

