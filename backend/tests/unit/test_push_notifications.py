import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import create_access_token
from models.user import User
from models.enums import UserRole


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


@pytest.mark.asyncio
async def test_register_and_list_device_tokens(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_push@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    await test_db.refresh(operator)
    token = make_token(operator)

    # 1. Register Android device
    reg_res1 = await async_client.post(
        "/api/v1/notifications/devices/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "token": "fcm_token_android_pixel_8_abc1234567890",
            "platform": "android",
            "device_name": "Google Pixel 8 Pro",
        },
    )
    assert reg_res1.status_code == 201
    assert reg_res1.json()["platform"] == "android"

    # 2. Register Web push token
    reg_res2 = await async_client.post(
        "/api/v1/notifications/devices/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "token": "web_push_subscription_chrome_xyz0987654321",
            "platform": "web",
            "device_name": "Chrome on MacOS",
        },
    )
    assert reg_res2.status_code == 201

    # 3. List active devices
    list_res = await async_client.get(
        "/api/v1/notifications/devices",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert list_res.status_code == 200
    devices = list_res.json()
    assert len(devices) == 2
    platforms = [d["platform"] for d in devices]
    assert "android" in platforms
    assert "web" in platforms


@pytest.mark.asyncio
async def test_unregister_device_token(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_unreg@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    await test_db.refresh(operator)
    token = make_token(operator)

    dev_token = "fcm_token_to_unregister_12345678"
    await async_client.post(
        "/api/v1/notifications/devices/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "token": dev_token,
            "platform": "ios",
            "device_name": "iPhone 15",
        },
    )

    # Unregister
    del_res = await async_client.delete(
        f"/api/v1/notifications/devices/{dev_token}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert del_res.status_code == 200

    # Verify device list is now empty
    list_res = await async_client.get(
        "/api/v1/notifications/devices",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert list_res.status_code == 200
    assert len(list_res.json()) == 0


@pytest.mark.asyncio
async def test_send_push_notification(
    async_client: AsyncClient,
    test_db: AsyncSession,
):
    operator = User(
        email="operator_send_push@example.com",
        password_hash="hash",
        role=UserRole.OPERATOR,
        site="Campus North",
        email_verified=True,
    )
    test_db.add(operator)
    await test_db.commit()
    await test_db.refresh(operator)
    token = make_token(operator)

    # Register device
    await async_client.post(
        "/api/v1/notifications/devices/register",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "token": "fcm_delivery_test_token_987654321",
            "platform": "android",
        },
    )

    # Send test push
    push_res = await async_client.post(
        "/api/v1/notifications/push/test",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "title": "P1 Outage Incident INC-2026-000100",
            "body": "Major Incident Declared: Core payment service is offline.",
            "data": {"case_id": "999", "priority": "P1"},
        },
    )
    assert push_res.status_code == 200
    p_data = push_res.json()
    assert p_data["sent_count"] == 1
    assert p_data["failed_count"] == 0
    assert p_data["status"] == "delivered"
