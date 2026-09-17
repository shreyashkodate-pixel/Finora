from typing import List
from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from db.session import get_db_session
from models.user import User
from api.deps import get_current_active_user
from schemas.push_notification import (
    DeviceTokenRegisterRequest,
    DeviceTokenResponse,
    SendPushTestRequest,
    SendPushResponse,
)
from services.push_notification_service import PushNotificationService

router = APIRouter(prefix="/notifications", tags=["Push Notifications (FCM/APNs)"])


@router.post("/devices/register", response_model=DeviceTokenResponse, status_code=status.HTTP_201_CREATED)
async def register_device_token(
    payload: DeviceTokenRegisterRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Registers a client device push token (Android FCM, iOS APNs, or WebPush).
    """
    return await PushNotificationService.register_device(
        db=db,
        user_id=current_user.id,
        token=payload.token,
        platform=payload.platform,
        device_name=payload.device_name,
    )


@router.delete("/devices/{token}", status_code=status.HTTP_200_OK)
async def unregister_device_token(
    token: str,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Unregisters a device push token upon logout.
    """
    success = await PushNotificationService.unregister_device(
        db=db,
        user_id=current_user.id,
        token=token,
    )
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "DEVICE_NOT_FOUND", "message": "Device token not found for this user."}},
        )
    return {"status": "unregistered", "token": token}


@router.get("/devices", response_model=List[DeviceTokenResponse], status_code=status.HTTP_200_OK)
async def list_user_devices(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Lists all active devices registered to the calling user.
    """
    return await PushNotificationService.list_user_devices(
        db=db,
        user_id=current_user.id,
    )


@router.post("/push/test", response_model=SendPushResponse, status_code=status.HTTP_200_OK)
async def send_test_push_notification(
    payload: SendPushTestRequest,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Sends a test push notification to all active devices registered to the calling user.
    """
    return await PushNotificationService.send_push_to_user(
        db=db,
        user_id=current_user.id,
        title=payload.title,
        body=payload.body,
        data=payload.data,
    )
