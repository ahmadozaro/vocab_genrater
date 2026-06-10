from fastapi import Depends, HTTPException

from fastapi.security import OAuth2PasswordBearer

from jose import JWTError, jwt

from sqlalchemy.orm import Session



from app import models

from app.core.database import get_db

from app.utils.security import ALGORITHM, SECRET_KEY





oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")





def get_current_user(

    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)

):

    try:

        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

        user_id = payload.get("user_id")



        if user_id is None:

            raise HTTPException(

                status_code=401, detail="Invalid token: missing user_id"

            )

        if payload.get("token_type", "access") != "access":

            raise HTTPException(status_code=401, detail="Invalid token type")



    except JWTError:

        raise HTTPException(status_code=401, detail="Invalid token: decode failed")



    user = db.query(models.User).filter(models.User.id == user_id).first()



    if user is None:

        raise HTTPException(status_code=401, detail="User not found")



    return user

