from pydantic import BaseModel, EmailStr
from typing import Optional, List, Union


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
    level_test_completed: bool = False
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


# ================= AUTH SCHEMAS =================
class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str
    code: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    code: str


class ResendVerificationRequest(BaseModel):
    email: EmailStr



