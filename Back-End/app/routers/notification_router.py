from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.core.database import get_db
from app.models.notification_model import Notification
from app.models.user_model import User
from app.schemas.notification_schema import NotificationResponse
from app.services.notification_service import NotificationService


router = APIRouter()


def _get_notification(
    db: Session, notification_id: int, user_id: int | None = None
) -> Notification:
    query = db.query(Notification).filter(Notification.id == notification_id)
    if user_id is not None:
        query = query.filter(Notification.user_id == user_id)
    notification = query.first()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


@router.get("/notifications", response_model=list[NotificationResponse])
def get_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )


@router.get("/notifications/unread-count")
def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    count = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id, Notification.is_read == False)
        .count()
    )
    return {"unreadCount": count}


@router.get("/notifications/sync", response_model=list[NotificationResponse])
def sync_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = NotificationService(db, current_user.id)
    service.sync_all()
    return (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )


# FIX #4: read-all MUST come before {notification_id}/read
# FastAPI matches routes in order — if {notification_id} comes first,
# "read-all" gets parsed as an int and raises HTTP 422.
@router.put("/notifications/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id, Notification.is_read == False)
        .update({"is_read": True})
    )
    db.commit()
    return {"message": "All notifications marked as read"}


@router.put("/notifications/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = _get_notification(db, notification_id, current_user.id)
    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification


@router.delete("/notifications/{notification_id}")
def delete_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = _get_notification(db, notification_id, current_user.id)
    db.delete(notification)
    db.commit()
    return {"message": "Notification deleted successfully"}