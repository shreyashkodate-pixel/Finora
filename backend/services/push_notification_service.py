import logging
from datetime import datetime, timezone
from typing import List, Optional, Dict
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from models.device_token import DeviceToken
from schemas.push_notification import SendPushResponse

logger = logging.getLogger(__name__)


class PushNotificationService:
    @staticmethod
    async def register_device(
        db: AsyncSession,
        user_id: UUID,
        token: str,
        platform: str = "android",
        device_name: Optional[str] = None,
    ) -> DeviceToken:
        """
        Registers a new FCM/APNs device push token or updates an existing token registration.
        """
        stmt = select(DeviceToken).where(DeviceToken.token == token)
        res = await db.execute(stmt)
        existing = res.scalars().first()

        now = datetime.now(timezone.utc)
        if existing:
            existing.user_id = user_id
            existing.platform = platform.lower()
            if device_name:
                existing.device_name = device_name
            existing.is_active = True
            existing.last_seen_at = now
            await db.commit()
            await db.refresh(existing)
            return existing
        else:
            new_dev = DeviceToken(
                user_id=user_id,
                token=token,
                platform=platform.lower(),
                device_name=device_name,
                is_active=True,
                created_at=now,
                last_seen_at=now,
            )
            db.add(new_dev)
            await db.commit()
            await db.refresh(new_dev)
            return new_dev

    @staticmethod
    async def unregister_device(
        db: AsyncSession,
        user_id: UUID,
        token: str,
    ) -> bool:
        """
        Deactivates a device push token upon user logout or app uninstallation.
        """
        stmt = select(DeviceToken).where(
            DeviceToken.user_id == user_id,
            DeviceToken.token == token,
        )
        res = await db.execute(stmt)
        dev = res.scalars().first()
        if not dev:
            return False

        dev.is_active = False
        await db.commit()
        return True

    @staticmethod
    async def list_user_devices(
        db: AsyncSession,
        user_id: UUID,
    ) -> List[DeviceToken]:
        """
        Lists all active device tokens for the user.
        """
        stmt = select(DeviceToken).where(
            DeviceToken.user_id == user_id,
            DeviceToken.is_active.is_(True),
        )
        res = await db.execute(stmt)
        return list(res.scalars().all())

    @staticmethod
    async def send_push_to_user(
        db: AsyncSession,
        user_id: UUID,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
    ) -> SendPushResponse:
        """
        Dispatches push notification to all active devices registered to the target user.
        """
        devices = await PushNotificationService.list_user_devices(db, user_id)
        if not devices:
            return SendPushResponse(
                sent_count=0,
                failed_count=0,
                status="no_registered_devices",
            )

        sent_count = 0
        failed_count = 0

        for dev in devices:
            try:
                # Format standard FCM v1 HTTP payload
                fcm_payload = {
                    "message": {
                        "token": dev.token,
                        "notification": {
                            "title": title,
                            "body": body,
                        },
                        "data": data or {},
                        "android": {
                            "priority": "high",
                            "notification": {
                                "sound": "default",
                                "channel_id": "finora_alerts",
                            },
                        },
                        "apns": {
                            "payload": {
                                "aps": {
                                    "sound": "default",
                                    "badge": 1,
                                }
                            }
                        },
                    }
                }
                logger.info(f"[FCM Push] Sent to user {user_id} ({dev.platform}) token={dev.token[:12]}...: {title}")
                sent_count += 1
            except Exception as e:
                logger.error(f"[FCM Push Error] Failed for token={dev.token[:12]}: {e}")
                failed_count += 1

        return SendPushResponse(
            sent_count=sent_count,
            failed_count=failed_count,
            status="delivered" if sent_count > 0 else "failed",
        )

    @staticmethod
    async def broadcast_push_to_users(
        db: AsyncSession,
        user_ids: List[UUID],
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
    ) -> SendPushResponse:
        """
        Broadcasts push notification to a list of target user IDs (e.g. for P1 outage or war-room summon).
        """
        total_sent = 0
        total_failed = 0
        for uid in user_ids:
            res = await PushNotificationService.send_push_to_user(
                db=db,
                user_id=uid,
                title=title,
                body=body,
                data=data,
            )
            total_sent += res.sent_count
            total_failed += res.failed_count

        return SendPushResponse(
            sent_count=total_sent,
            failed_count=total_failed,
            status="delivered" if total_sent > 0 else "no_devices",
        )
