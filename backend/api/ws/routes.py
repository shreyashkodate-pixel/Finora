import json
import logging
import uuid
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import decode_jwt_token
from db.session import get_db_session
from models.case import Case
from models.enums import UserRole
from models.user import User
from realtime.connection_manager import ws_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ws", tags=["Real-time WebSockets"])


@router.websocket("/cases/{case_id}")
async def websocket_case_endpoint(
    websocket: WebSocket,
    case_id: str,
    token: str = Query(..., description="JWT Bearer access token"),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Real-time bidirectional WebSocket channel for live case updates, messages, and typing indicators.
    """
    # 1. Validate JWT Token
    try:
        payload = decode_jwt_token(token)
        user_id = payload.get("sub")
        role_str = payload.get("role")
        if not user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    except Exception as e:
        logger.warning(f"WebSocket auth failed: {e}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # 2. Check Case Access in DB
    try:
        case_uuid = uuid.UUID(case_id)
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    case_stmt = select(Case).where(Case.id == case_uuid)
    case_res = await db.execute(case_stmt)
    case = case_res.scalar_one_or_none()
    if not case:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Requesters can only access their own cases
    if role_str == UserRole.REQUESTER.value and case.requester_id != user_uuid:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return


    # 3. Connect to Room
    await ws_manager.connect(case_id, websocket)

    try:
        while True:
            data_text = await websocket.receive_text()
            try:
                msg_json = json.loads(data_text)
                action = msg_json.get("action")
                if action == "typing":
                    await ws_manager.broadcast_to_case(
                        case_id=case_id,
                        event_type="TYPING_INDICATOR",
                        data={"user_id": user_id, "is_typing": bool(msg_json.get("is_typing", True))},
                    )
                elif action == "ping":
                    await websocket.send_text(json.dumps({"event": "pong"}))
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        ws_manager.disconnect(case_id, websocket)
    except Exception as exc:
        logger.error(f"WebSocket session error: {exc}")
        ws_manager.disconnect(case_id, websocket)
