from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel

from app.schemas.question_schema import QuestionResponse


class QuizCreate(BaseModel):
    quizType: Optional[str] = "vocabulary"
    wordList: Optional[str] = None
    questionsCount: Optional[int] = 0
    userId: Optional[int] = None


class QuizResponse(BaseModel):
    quizId: int
    quizType: Optional[str] = None
    wordList: Optional[str] = None
    score: int = 0
    questionsCount: Optional[int] = 0
    date: datetime
    userId: Optional[int] = None

    class Config:
        from_attributes = True


class QuizSubmitRequest(BaseModel):
    answers: List[str]


class QuizSubmitResponse(BaseModel):
    quizId: int
    score: int
    total: int


class QuizWithQuestionsResponse(BaseModel):
    quiz_id: int
    questions: List[QuestionResponse]


class QuizStartQuestion(BaseModel):
    question: str
    options: List[str]
    correctAnswer: str


class QuizStartResponse(BaseModel):
    quiz_id: int
    questions: List[QuizStartQuestion]


QuizSubmit = QuizSubmitRequest
QuizResult = QuizSubmitResponse
QuizHistory = QuizResponse
