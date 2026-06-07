from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class SM2QuestionResponse(BaseModel):
    itemId: int
    userWordId: int
    questionText: str
    questionType: str = "meaning_to_word"
    options: List[str]


class SM2StartResponse(BaseModel):
    quizId: int
    questions: List[SM2QuestionResponse]


class SM2Answer(BaseModel):
    itemId: int
    answer: Optional[str] = None
    durationSeconds: Optional[int] = Field(default=None, ge=0)
    skipped: bool = False


class SM2SubmitRequest(BaseModel):
    answers: List[SM2Answer]
    confirmEmptyAsWrong: bool = False


class SM2ItemResult(BaseModel):
    itemId: int
    wordId: int
    word: str
    isCorrect: bool
    quality: int
    sm2: dict
    oldScore: int
    newScore: int
    scoreDelta: int
    oldRepeats: int
    newRepeats: int
    oldNextReviewDate: Optional[datetime] = None
    newNextReviewDate: Optional[datetime] = None
    status: str
    errorType: str
    learningInsight: str
    smartAction: str
    achievementFlags: List[str] = Field(default_factory=list)


class SM2SubmitResponse(BaseModel):
    quizId: int
    score: int
    total: int
    countsForStreak: bool
    dailyStreak: int
    results: List[SM2ItemResult]


class SM2DueResponse(BaseModel):
    dueCount: int
    overdueCount: int
    hardCount: int = 0
    pendingCount: int
    nextReviewAt: Optional[datetime] = None
