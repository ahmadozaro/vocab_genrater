import logging

import random

import string

from datetime import datetime, timedelta



from fastapi import APIRouter, Depends, HTTPException, Request

from jose import JWTError, jwt

from sqlalchemy.orm import Session



from app.core.config import settings

from app.core.database import get_db

from app.services.email_service import (

    EmailDeliveryError,

    is_email_enabled,

    send_password_reset_code,

    send_verification_code,

)



logger = logging.getLogger(__name__)

from app.models.notification_model import Notification

from app.models.interest_model import Interest

from app.models.progress_model import Progress

from app.models.refresh_token_model import RefreshToken

from app.models.user_model import User

from app.schemas.user_schema import (

    ForgotPasswordRequest,

    LoginRequest,

    ResendVerificationRequest,

    ResetPasswordRequest,

    UserCreate,

    UserResponse,

    UserUpdateLevel,

    UserUpdateInterests,

    UserUpdatePassword,

    UserUpdateProfile,

    DeleteAccountRequest,

    VerifyEmailRequest,

)

from app.utils.security import (

    ALGORITHM,

    SECRET_KEY,

    create_access_token,

    create_refresh_token,

    hash_token,

    hash_password,

    verify_password,

)

from app.auth import get_current_user



router = APIRouter()





                                                          

def _get_user_in_db(current_user: User, db: Session) -> User:

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

    level_test_completed = bool(user.level_test_completed)

    if user.level and not level_test_completed:

        level_test_completed = True

    return {

        "id": user.id,

        "name": user.name,

        "email": user.email,

        "level": user.level,

        "level_test_completed": level_test_completed,

        "interests": ",".join(interest.name for interest in user.interests),

        "is_email_verified": bool(user.is_email_verified),

    }





def _new_email_code() -> str:

    return "".join(random.choices(string.digits, k=6))





def _normalize_email(value: str | None) -> str:

    return (value or "").strip().lower()





async def _login_credentials(request: Request) -> LoginRequest:

    content_type = request.headers.get("content-type", "")

    if "application/json" in content_type:

        body = await request.json()

        return LoginRequest(

            email=body.get("email") or body.get("username") or "",

            password=body.get("password") or "",

        )

    form = await request.form()

    return LoginRequest(

        email=form.get("username") or form.get("email") or "",

        password=form.get("password") or "",

    )





def _token_pair(user: User, db: Session) -> dict:

    payload = {"user_id": user.id}

    refresh_token = create_refresh_token(payload)

    db.add(

        RefreshToken(

            user_id=user.id,

            token_hash=hash_token(refresh_token),

            expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),

        )

    )

    db.flush()

    return {

        "access_token": create_access_token(payload),

        "refresh_token": refresh_token,

        "token_type": "bearer",

    }





                                                        





@router.get("/auth/email/config-status")

def email_config_status(current_user: User = Depends(get_current_user)):

    from app.services.email_service import is_smtp_enabled



    return {

        "smtp_host_present": bool(settings.SMTP_HOST.strip()),

        "smtp_username_present": bool(settings.SMTP_USERNAME.strip()),

        "smtp_password_present": bool(settings.SMTP_PASSWORD.strip()),

        "smtp_from_email_present": bool(settings.SMTP_FROM_EMAIL.strip()),

        "smtp_enabled": is_smtp_enabled(),

        "email_enabled_any": is_smtp_enabled(),

    }





                                              





@router.post("/register")

def register_user(user: UserCreate, db: Session = Depends(get_db)):

    email = _normalize_email(user.email)

    existing_user = db.query(User).filter(User.email == email).first()

    if existing_user:

        raise HTTPException(status_code=400, detail="Email already exists")



    code = _new_email_code()

    new_user = User(

        name=user.name,

        email=email,

        password=hash_password(user.password),

        email_verification_code=code,

        email_verification_expires_at=datetime.utcnow() + timedelta(minutes=10),

        email_verification_last_sent_at=datetime.utcnow(),

        is_email_verified=0,

    )

    db.add(new_user)

    db.commit()



    progress = Progress(user_id=new_user.id)

    db.add(progress)

    db.commit()



    verification_sent = False

    if is_email_enabled():

        try:

            send_verification_code(new_user.email, code)

            verification_sent = True

        except EmailDeliveryError:

            pass



    welcome = Notification(

        user_id=new_user.id,

        title="Welcome to AI VocabGen!",

        message="Start adding words and complete your first review quiz.",

        type="welcome",

    )

    db.add(welcome)

    db.commit()



    db.refresh(new_user)



    data = {

        "user": _user_response(new_user),

        **_token_pair(new_user, db),

        "verification_sent": verification_sent,

    }

    if not is_email_enabled():

        data["verification_debug_code"] = code

    db.commit()

    return data





                                                  





@router.post("/auth/verify-email")

def verify_email(

    data: VerifyEmailRequest,

    db: Session = Depends(get_db),

):

    user = db.query(User).filter(User.email == _normalize_email(data.email)).first()

    if not user:

        raise HTTPException(status_code=404, detail="Email not registered")

    if user.is_email_verified:

        response = {

            "message": "Email already verified",

            "is_email_verified": True,

            **_token_pair(user, db),

        }

        db.commit()

        return response



    if not user.email_verification_code:

        raise HTTPException(status_code=400, detail="No verification code sent")



    if user.email_verification_expires_at and user.email_verification_expires_at < datetime.utcnow():

        raise HTTPException(status_code=400, detail="Verification code has expired. Request a new one.")



    if user.email_verification_attempts and user.email_verification_attempts >= 5:

        raise HTTPException(status_code=429, detail="Too many invalid attempts. Request a new code.")



    if user.email_verification_code != data.code:

        user.email_verification_attempts = (user.email_verification_attempts or 0) + 1

        db.commit()

        remaining = 5 - user.email_verification_attempts

        raise HTTPException(

            status_code=400,

            detail=f"Invalid code. {remaining} attempt(s) remaining.",

        )



    user.is_email_verified = 1

    user.email_verification_code = None

    user.email_verification_expires_at = None

    user.email_verification_last_sent_at = None

    user.email_verification_attempts = 0

    db.commit()



    response = {

        "message": "Email verified successfully",

        **_token_pair(user, db),

        "is_email_verified": True,

    }

    db.commit()

    return response





@router.post("/auth/email/send-verification")

@router.post("/auth/email/resend-verification")

@router.post("/auth/resend-verification")

def resend_verification(

    data: ResendVerificationRequest,

    db: Session = Depends(get_db),

):

    user = db.query(User).filter(User.email == _normalize_email(data.email)).first()

    if not user:

        raise HTTPException(status_code=404, detail="Email not registered")

    if user.is_email_verified:

        return {"message": "Email already verified", "is_email_verified": True}



                                     

    if user.email_verification_last_sent_at:

        elapsed = (datetime.utcnow() - user.email_verification_last_sent_at).total_seconds()

        if elapsed < 60:

            remaining = int(60 - elapsed)

            raise HTTPException(

                status_code=429,

                detail=f"Please wait {remaining} seconds before requesting a new code.",

            )



    code = _new_email_code()

    user.email_verification_code = code

    user.email_verification_expires_at = datetime.utcnow() + timedelta(minutes=10)

    user.email_verification_last_sent_at = datetime.utcnow()

    user.email_verification_attempts = 0



    sent = False

    if is_email_enabled():

        try:

            send_verification_code(user.email, code)

            sent = True

        except EmailDeliveryError:

            pass



    db.commit()

    response = {"message": "Verification code sent", "sent": sent}

    if not is_email_enabled():

        response["debug_code"] = code

    return response





                                           





@router.post("/login")

async def login(

    request: Request,

    db: Session = Depends(get_db),

):

    credentials = await _login_credentials(request)

    email = _normalize_email(credentials.email)

    user = db.query(User).filter(User.email == email).first()

    if not user:

        logger.info("Login failed: user not found for email=%s", email)

        raise HTTPException(status_code=400, detail="Invalid email or password")

    if not verify_password(credentials.password, user.password):

        logger.info("Login failed: wrong password for email=%s", email)

        raise HTTPException(status_code=400, detail="Invalid email or password")



    response = {

        **_token_pair(user, db),

        "user": _user_response(user),

    }

    db.commit()

    return response





@router.post("/auth/refresh")

def refresh_token(data: dict, db: Session = Depends(get_db)):

    token = data.get("refresh_token") if isinstance(data, dict) else None

    if not token:

        raise HTTPException(status_code=401, detail="Missing refresh token")

    try:

        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

        if payload.get("token_type") != "refresh":

            raise HTTPException(status_code=401, detail="Invalid refresh token")

        user_id = payload.get("user_id")

    except JWTError:

        raise HTTPException(status_code=401, detail="Invalid refresh token")

    stored_token = (

        db.query(RefreshToken)

        .filter(RefreshToken.token_hash == hash_token(token))

        .first()

    )

    if (

        not stored_token

        or stored_token.revoked_at is not None

        or stored_token.expires_at < datetime.utcnow()

        or stored_token.user_id != user_id

    ):

        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = db.query(User).filter(User.id == user_id).first()

    if not user:

        raise HTTPException(status_code=401, detail="User not found")

    stored_token.revoked_at = datetime.utcnow()

    response = {**_token_pair(user, db), "user": _user_response(user)}

    db.commit()

    return response





@router.post("/auth/logout")

def logout(data: dict, db: Session = Depends(get_db)):

    token = data.get("refresh_token") if isinstance(data, dict) else None

    if token:

        stored_token = (

            db.query(RefreshToken)

            .filter(RefreshToken.token_hash == hash_token(token))

            .first()

        )

        if stored_token and stored_token.revoked_at is None:

            stored_token.revoked_at = datetime.utcnow()

            db.commit()

    return {"message": "Logged out successfully"}





                                                             





@router.post("/auth/forgot-password")

def forgot_password(

    email_data: ForgotPasswordRequest,

    db: Session = Depends(get_db),

):

    user = db.query(User).filter(User.email == _normalize_email(email_data.email)).first()

    if not user:

        raise HTTPException(status_code=404, detail="Email not registered")



    reset_code = "".join(random.choices(string.digits, k=6))

    user.reset_code = reset_code

    user.reset_code_expires_at = datetime.utcnow() + timedelta(minutes=15)

    if is_email_enabled():

        try:

            send_password_reset_code(user.email, reset_code)

        except EmailDeliveryError:

            db.rollback()

            raise HTTPException(

                status_code=502,

                detail="Could not send password reset email. Please try again later.",

            )



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

    user = db.query(User).filter(User.email == _normalize_email(data.email)).first()

    if not user or user.reset_code != data.code:

        raise HTTPException(status_code=400, detail="Invalid reset code")

    if not user.reset_code_expires_at or user.reset_code_expires_at < datetime.utcnow():

        user.reset_code = None

        user.reset_code_expires_at = None

        db.commit()

        raise HTTPException(status_code=400, detail="Reset code has expired")



    user.password = hash_password(data.new_password)

    user.reset_code = None

    user.reset_code_expires_at = None

    db.commit()

    return {"message": "Password reset successfully"}





                                                              





@router.get("/users/me", response_model=UserResponse, response_model_exclude_none=True)

def get_me(

    current_user: User = Depends(get_current_user),

    db: Session = Depends(get_db),

):

    return _user_response(_get_user_in_db(current_user, db))





                                                  





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



    user = _get_user_in_db(current_user, db)

    user.level = data.level

    if not user.level_test_completed:

        user.level_test_completed = 1

        user.level_test_completed_at = datetime.utcnow()

    db.commit()

    db.refresh(user)

    return _user_response(user)





                                                      





@router.patch("/users/me/interests", response_model=UserResponse, response_model_exclude_none=True)

def update_interests(

    data: UserUpdateInterests,

    db: Session = Depends(get_db),

    current_user: User = Depends(get_current_user),

):

    user = _get_user_in_db(current_user, db)

    user.interests = _get_or_create_interests(db, data.interests)

    db.commit()

    db.refresh(user)

    return _user_response(user)





                                                         





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





@router.delete("/users/me")

def delete_my_account(

    data: DeleteAccountRequest,

    db: Session = Depends(get_db),

    current_user: User = Depends(get_current_user),

):

    user = _get_user_in_db(current_user, db)

    if not verify_password(data.password, user.password):

        raise HTTPException(status_code=401, detail="Invalid current password")



    db.query(RefreshToken).filter(RefreshToken.user_id == user.id).delete(synchronize_session=False)

    db.delete(user)

    db.commit()

    return {"message": "Account deleted successfully"}





@router.patch("/users/me", response_model=UserResponse, response_model_exclude_none=True)

def update_profile(

    data: UserUpdateProfile,

    db: Session = Depends(get_db),

    current_user: User = Depends(get_current_user),

):

    user = _get_user_in_db(current_user, db)

    if data.name is not None:

        user.name = data.name

    if data.email is not None:

        new_email = _normalize_email(data.email)

        existing_user = (

            db.query(User)

            .filter(User.email == new_email, User.id != user.id)

            .first()

        )

        if existing_user:

            raise HTTPException(status_code=400, detail="Email already exists")

        user.email = new_email

    if data.level is not None:

        user.level = data.level

    if data.interests is not None:

        user.interests = _get_or_create_interests(db, data.interests)

    db.commit()

    db.refresh(user)

    return _user_response(user)



