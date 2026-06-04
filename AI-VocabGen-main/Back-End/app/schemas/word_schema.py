from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class WordCreate(BaseModel):
    text: str
    arabicMeaning: Optional[str] = None
    translationAr: Optional[str] = None
    audio: Optional[str] = None
    source: Optional[str] = None
    examples: List[str] = []
    generatedSentence: Optional[str] = None


class WordLookupRequest(BaseModel):
    text: str
    level: Optional[str] = None
    user_id: Optional[int] = None


class WordLookupResponse(BaseModel):
    text: str
    arabicMeaning: Optional[str] = None
    translationAr: Optional[str] = None
    translationProvider: Optional[str] = None
    aiMeaningAr: Optional[str] = None
    definition: Optional[str] = None
    examples: List[str] = []
    source: str = "translation+ai"


class WordUpdate(BaseModel):
    text: Optional[str] = None
    arabicMeaning: Optional[str] = None
    translationAr: Optional[str] = None
    audio: Optional[str] = None
    source: Optional[str] = None
    score: Optional[int] = None
    status: Optional[str] = None
    nextReviewDate: Optional[datetime] = None


class WordResponse(BaseModel):
    wordId: int
    text: str
    normalizedText: Optional[str] = None
    arabicMeaning: Optional[str] = None
    translationAr: Optional[str] = None
    translationProvider: Optional[str] = None
    aiMeaningAr: Optional[str] = None
    aiDefinitionEn: Optional[str] = None
    audio: Optional[str] = None
    sm2Repeats: int = 0
    sm2EaseFactor: float = 2.5
    sm2IntervalDays: int = 0
    nextReviewDate: Optional[datetime] = None
    lastReviewedAt: Optional[datetime] = None
    lastQuality: Optional[int] = None
    correctStreak: int = 0
    wrongStreak: int = 0
    score: int = 0
    status: str = "new"
    isActive: bool = True
    activationDate: Optional[datetime] = None
    source: Optional[str] = None
    userId: Optional[int] = None
    addedAt: Optional[datetime] = None
    examples: List[str] = []

    class Config:
        from_attributes = True
