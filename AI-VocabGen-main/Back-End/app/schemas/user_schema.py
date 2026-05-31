from pydantic import BaseModel, EmailStr
from typing import Optional, List, Union
from datetime import datetime


# ================= USER SCHEMAS =================
class UserCreate(BaseModel):
    name: str
    email: str
    password: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    level: Optional[str] = None
    interests: str = ""
    is_email_verified: bool = False
    verification_debug_code: Optional[str] = None

    class Config:
        from_attributes = True


class UserUpdateLevel(BaseModel):
    level: str  # مطلوب بواسطة user_router


class UserUpdateInterests(BaseModel):
    interests: Union[List[str], str] = []


class UserUpdateProfile(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    level: Optional[str] = None
    interests: Optional[Union[List[str], str]] = None


class UserUpdatePassword(BaseModel):
    current_password: str
    new_password: str


# ================= WORD & SENTENCE SCHEMAS =================
class SentenceInWord(BaseModel):
    sentenceId: int
    text: str

    class Config:
        from_attributes = True


class WordCreate(BaseModel):
    text: str
    arabicMeaning: Optional[str] = None
    audio: Optional[str] = None
    source: Optional[str] = None


class WordResponse(BaseModel):
    wordId: int
    text: str
    arabicMeaning: Optional[str]
    audio: Optional[str]
    sm2Repeats: int
    nextReviewDate: Optional[datetime]
    score: int
    source: Optional[str]
    sentences: List[SentenceInWord] = []

    class Config:
        from_attributes = True


# ================= AUTH SCHEMAS =================
class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str
    code: str


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    code: str


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class LoginOtpVerifyRequest(BaseModel):
    email: EmailStr
    challenge_id: str
    code: str


class LoginOtpResendRequest(BaseModel):
    email: EmailStr
    challenge_id: str
