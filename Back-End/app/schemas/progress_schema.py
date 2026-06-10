from datetime import date, datetime

from typing import Optional



from pydantic import BaseModel





class ProgressCreate(BaseModel):

    userId: int

    dailyStreak: int = 0

    masteredWords: int = 0

    newWords: int = 0

    completedDailyQuizzes: int = 0

    completedSm2Quizzes: int = 0

    notifications: int = 0





class ProgressUpdate(BaseModel):

    userId: Optional[int] = None

    dailyStreak: Optional[int] = None

    masteredWords: Optional[int] = None

    newWords: Optional[int] = None

    completedDailyQuizzes: Optional[int] = None

    completedSm2Quizzes: Optional[int] = None

    notifications: Optional[int] = None





class ProgressResponse(BaseModel):

    id: int

    userId: int

    dailyStreak: int

    masteredWords: int

    newWords: int = 0

    activeWordsCount: int = 0

    dueReviewCount: int = 0

    completedDailyQuizzes: int = 0

    completedSm2Quizzes: int = 0

    lastSm2QuizDate: Optional[date] = None

    notifications: int = 0

    created_at: datetime

