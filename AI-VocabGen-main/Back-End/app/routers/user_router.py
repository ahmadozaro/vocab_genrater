import random
import string
from datetime import datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.schemas.user_schema import UserUpdatePassword  # ← أضف للـ imports

from app.core.database import get_db
from app.models.interest_model import Interest
from app.models.user_model import User
from app.services.email_service import (
    EmailDeliveryError,
    is_email_enabled,
    send_login_otp_code,
    send_password_reset_code,
    send_verification_code,
)
from app.schemas.user_schema import (
    ForgotPasswordRequest,
    LoginOtpResendRequest,
    LoginOtpVerifyRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    UserCreate,
    UserResponse,
    UserUpdateLevel,
    UserUpdateInterests,
    UserUpdateProfile,
    VerifyEmailRequest,
)
from app.utils.security import hash_password, verify_password, create_access_token
from app.auth import get_current_user
from fastapi.security import OAuth2PasswordRequestForm

router = APIRouter()


# ─── Helper: جيب المستخدم من نفس الـ db ──────────────────────
def _get_user_in_db(current_user: User, db: Session) -> User:
    """يجيب المستخدم من نفس الـ session حتى يشتغل db.refresh صح"""
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def _parse_interest_names(raw_interests) -> list[str]:
    if raw_interests is None:
        return []
    if isinstance(raw_interests, str):
        return [name.strip() for name in raw_interests.split(",") if name.strip()]
    return [str(name).strip() for name in raw_interests if str(name).strip()]


def _get_or_create_interests(db: Session, raw_interests) -> list[Interest]:
    interests = []
    for name in _parse_interest_names(raw_interests):
        interest = db.query(Interest).filter(Interest.name == name).first()
        if not interest:
            interest = Interest(name=name)
            db.add(interest)
            db.flush()
        interests.append(interest)
    return interests


def _user_response(user: User) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "level": user.level,
        "interests": ",".join(interest.name for interest in user.interests),
        "is_email_verified": bool(user.is_email_verified),
    }


def _new_email_code() -> str:
    return "".join(random.choices(string.digits, k=6))


LOGIN_OTP_TTL_MINUTES = 5
LOGIN_OTP_MAX_ATTEMPTS = 5
LOGIN_OTP_MAX_RESENDS = 3


def _clear_login_otp(user: User) -> None:
    user.login_otp_code = None
    user.login_otp_expires_at = None
    user.login_otp_used = True
    user.login_otp_attempts = 0
    user.login_otp_resend_count = 0
    user.login_otp_challenge_id = None
    user.login_otp_last_sent_at = None


def _create_login_otp(user: User, *, resend: bool = False) -> str:
    if resend and user.login_otp_resend_count >= LOGIN_OTP_MAX_RESENDS:
        raise HTTPException(
            status_code=429,
            detail="Too many resend attempts. Please login again.",
        )

    user.login_otp_code = _new_email_code()
    user.login_otp_expires_at = datetime.utcnow() + timedelta(
        minutes=LOGIN_OTP_TTL_MINUTES
    )
    user.login_otp_used = False
    user.login_otp_attempts = 0
    user.login_otp_last_sent_at = datetime.utcnow()
    if resend:
        user.login_otp_resend_count += 1
    else:
        user.login_otp_resend_count = 0
        user.login_otp_challenge_id = str(uuid4())

    if is_email_enabled():
        try:
            send_login_otp_code(user.email, user.login_otp_code)
        except EmailDeliveryError as exc:
            raise HTTPException(
                status_code=502,
                detail="Could not send login verification email. Please try again later.",
            ) from exc

    return user.login_otp_challenge_id


# ================= REGISTER =================


@router.post("/register", response_model=UserResponse, response_model_exclude_none=True)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already exists")

    new_user = User(
        name=user.name,
        email=user.email,
        password=hash_password(user.password),
        email_verification_code=_new_email_code(),
        is_email_verified=0,
    )
    db.add(new_user)
    if is_email_enabled():
        try:
            send_verification_code(new_user.email, new_user.email_verification_code)
        except EmailDeliveryError as exc:
            db.rollback()
            raise HTTPException(
                status_code=502,
                detail="Could not send verification email. Please try again later.",
            ) from exc

    db.commit()
    db.refresh(new_user)
    data = _user_response(new_user)
    if not is_email_enabled():
        data["verification_debug_code"] = new_user.email_verification_code
    return data


@router.post("/auth/verify-email")
def verify_email(
    data: VerifyEmailRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not registered")
    if user.is_email_verified:
        token = create_access_token({"user_id": user.id})
        return {
            "message": "Email already verified",
            "access_token": token,
            "token_type": "bearer",
        }
    if not user.email_verification_code or user.email_verification_code != data.code:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    user.is_email_verified = 1
    user.email_verification_code = None
    db.commit()
    token = create_access_token({"user_id": user.id})
    return {
        "message": "Email verified successfully",
        "access_token": token,
        "token_type": "bearer",
    }


@router.post("/auth/resend-verification")
def resend_verification(
    data: ResendVerificationRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not registered")
    if user.is_email_verified:
        return {"message": "Email already verified"}

    user.email_verification_code = _new_email_code()
    if is_email_enabled():
        try:
            send_verification_code(user.email, user.email_verification_code)
        except EmailDeliveryError as exc:
            db.rollback()
            raise HTTPException(
                status_code=502,
                detail="Could not send verification email. Please try again later.",
            ) from exc

    db.commit()
    response = {"message": "Verification code sent"}
    if not is_email_enabled():
        response["debug_code"] = user.email_verification_code
    return response


# ================= LOGIN =================


@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid email")
    if not verify_password(form_data.password, user.password):
        raise HTTPException(status_code=400, detail="Invalid password")
    if not user.is_email_verified:
        raise HTTPException(status_code=403, detail="Please verify your email first")

    challenge_id = _create_login_otp(user)
    db.commit()
    response = {
        "requires_2fa": True,
        "challenge_id": challenge_id,
        "message": "Login verification code sent",
        "expires_in_seconds": LOGIN_OTP_TTL_MINUTES * 60,
    }
    if not is_email_enabled():
        response["debug_code"] = user.login_otp_code
    return response


@router.post("/auth/login/verify-otp")
def verify_login_otp(
    data: LoginOtpVerifyRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or user.login_otp_challenge_id != data.challenge_id:
        raise HTTPException(status_code=400, detail="Invalid login challenge")

    if user.login_otp_used or not user.login_otp_code:
        raise HTTPException(status_code=400, detail="Login code already used")

    if not user.login_otp_expires_at or user.login_otp_expires_at < datetime.utcnow():
        _clear_login_otp(user)
        db.commit()
        raise HTTPException(status_code=400, detail="Login code has expired")

    if user.login_otp_attempts >= LOGIN_OTP_MAX_ATTEMPTS:
        _clear_login_otp(user)
        db.commit()
        raise HTTPException(
            status_code=429,
            detail="Too many invalid attempts. Please login again.",
        )

    if user.login_otp_code != data.code:
        user.login_otp_attempts += 1
        db.commit()
        remaining = LOGIN_OTP_MAX_ATTEMPTS - user.login_otp_attempts
        raise HTTPException(
            status_code=400,
            detail=f"Invalid login code. {remaining} attempts remaining.",
        )

    _clear_login_otp(user)
    db.commit()
    token = create_access_token({"user_id": user.id})
    return {"access_token": token, "token_type": "bearer"}


@router.post("/auth/login/resend-otp")
def resend_login_otp(
    data: LoginOtpResendRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or user.login_otp_challenge_id != data.challenge_id:
        raise HTTPException(status_code=400, detail="Invalid login challenge")
    if user.login_otp_used or not user.login_otp_code:
        raise HTTPException(status_code=400, detail="Login challenge is not active")
    if not user.login_otp_expires_at or user.login_otp_expires_at < datetime.utcnow():
        _clear_login_otp(user)
        db.commit()
        raise HTTPException(status_code=400, detail="Login code has expired")

    _create_login_otp(user, resend=True)
    db.commit()
    response = {
        "message": "Login verification code sent",
        "challenge_id": user.login_otp_challenge_id,
        "expires_in_seconds": LOGIN_OTP_TTL_MINUTES * 60,
        "resends_remaining": LOGIN_OTP_MAX_RESENDS - user.login_otp_resend_count,
    }
    if not is_email_enabled():
        response["debug_code"] = user.login_otp_code
    return response


@router.post("/auth/forgot-password")
def forgot_password(
    email_data: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == email_data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Email not registered")

    reset_code = "".join(random.choices(string.digits, k=6))
    user.reset_code = reset_code
    if is_email_enabled():
        try:
            send_password_reset_code(user.email, reset_code)
        except EmailDeliveryError as exc:
            db.rollback()
            raise HTTPException(
                status_code=502,
                detail="Could not send password reset email. Please try again later.",
            ) from exc

    db.commit()

    response = {"message": "Reset code sent"}
    if not is_email_enabled():
        response["debug_code"] = reset_code
    return response


@router.post("/auth/reset-password")
def reset_password(
    data: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == data.email).first()

    if not user or user.reset_code != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    user.password = hash_password(data.new_password)
    user.reset_code = None
    db.commit()

    return {"message": "Password reset successfully"}


# ================= GET ALL USERS =================


@router.get("/users", response_model=list[UserResponse], response_model_exclude_none=True)
def get_users(db: Session = Depends(get_db)):
    return [_user_response(user) for user in db.query(User).all()]


# ================= GET CURRENT USER PROFILE =================


@router.get("/users/me", response_model=UserResponse, response_model_exclude_none=True)
def get_me(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # نجيب من نفس الـ db لضمان البيانات محدّثة
    return _user_response(_get_user_in_db(current_user, db))


@router.get("/user/settings", response_model=UserResponse, response_model_exclude_none=True)
def get_user_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _user_response(_get_user_in_db(current_user, db))


# ================= UPDATE LEVEL =================


@router.patch("/users/me/level", response_model=UserResponse, response_model_exclude_none=True)
def update_level(
    data: UserUpdateLevel,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    valid_levels = ["A1", "A2", "B1", "B2", "C1"]
    if data.level not in valid_levels:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid level. Must be one of: {valid_levels}",
        )

    # ← الحل: نجيب المستخدم من نفس الـ db
    user = _get_user_in_db(current_user, db)
    user.level = data.level
    db.commit()
    db.refresh(user)
    return _user_response(user)


# ================= UPDATE INTERESTS =================


@router.patch("/users/me/interests", response_model=UserResponse, response_model_exclude_none=True)
def update_interests(
    data: UserUpdateInterests,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ← الحل: نجيب المستخدم من نفس الـ db
    user = _get_user_in_db(current_user, db)
    user.interests = _get_or_create_interests(db, data.interests)
    db.commit()
    db.refresh(user)
    return _user_response(user)


# ================= UPDATE FULL PROFILE =================


@router.patch("/users/me/password")
def update_password(
    data: UserUpdatePassword,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = _get_user_in_db(current_user, db)

    if not verify_password(data.current_password, user.password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    user.password = hash_password(data.new_password)
    db.commit()
    return {"message": "Password updated successfully"}


@router.patch("/users/me", response_model=UserResponse, response_model_exclude_none=True)
def update_profile(
    data: UserUpdateProfile,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ← الحل: نجيب المستخدم من نفس الـ db
    user = _get_user_in_db(current_user, db)

    if data.name is not None:
        user.name = data.name
    if data.email is not None:
        existing_user = (
            db.query(User)
            .filter(User.email == data.email, User.id != user.id)
            .first()
        )
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already exists")
        user.email = data.email
    if data.level is not None:
        user.level = data.level
    if data.interests is not None:
        user.interests = _get_or_create_interests(db, data.interests)

    db.commit()
    db.refresh(user)
    return _user_response(user)


@router.patch("/user/settings", response_model=UserResponse, response_model_exclude_none=True)
def update_user_settings(
    data: UserUpdateProfile,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_profile(data=data, db=db, current_user=current_user)
