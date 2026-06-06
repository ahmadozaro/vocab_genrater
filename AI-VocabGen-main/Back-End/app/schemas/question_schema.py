from typing import List

from pydantic import BaseModel


class QuestionCreate(BaseModel):
    questionText: str
    correctAnswer: str
    options: List[str]


class QuestionResponse(BaseModel):
    questionId: int
    questionText: str
    correctAnswer: str
    options: List[str]

    class Config:
        from_attributes = True
