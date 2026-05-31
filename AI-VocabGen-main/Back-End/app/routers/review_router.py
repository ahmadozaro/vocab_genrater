from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.core.database import get_db
from app.models.user_model import User
from app.models.word_model import Word
from app.schemas.word_schema import WordResponse


router = APIRouter()


def _is_due(review_date) -> bool:
    if not review_date:
        return True
    if isinstance(review_date, datetime):
        return review_date <= datetime.utcnow()
    try:
        parsed_date = datetime.fromisoformat(str(review_date).replace("Z", "+00:00"))
        if parsed_date.tzinfo is not None:
            parsed_date = parsed_date.replace(tzinfo=None)
        return parsed_date <= datetime.utcnow()
    except ValueError:
        return True


@router.get("/review/due", response_model=list[WordResponse])
def get_due_review_words(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    words = (
        db.query(Word)
        .filter(
            Word.user_id == current_user.id,
            Word.status != "pending",
        )
        .all()
    )
    return [word for word in words if _is_due(word.next_review_at)]
