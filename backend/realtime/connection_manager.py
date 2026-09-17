import json
import logging
from typing import Dict, List, Set, Any
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """
    Manages active WebSocket connections partitioned by case_id for ticket collaboration.
    """

    def __init__(self):
        # Maps case_id (str) -> Set of active WebSocket connections
        self._case_rooms: Dict[str, Set[WebSocket]] = {}

    async def connect(self, case_id: str, websocket: WebSocket):
        await websocket.accept()
        if case_id not in self._case_rooms:
            self._case_rooms[case_id] = set()
        self._case_rooms[case_id].add(websocket)
        logger.info(f"WebSocket client connected to case room: {case_id} (total: {len(self._case_rooms[case_id])})")

    def disconnect(self, case_id: str, websocket: WebSocket):
        if case_id in self._case_rooms:
            self._case_rooms[case_id].discard(websocket)
            if not self._case_rooms[case_id]:
                del self._case_rooms[case_id]
        logger.info(f"WebSocket client disconnected from case room: {case_id}")

    async def broadcast_to_case(self, case_id: str, event_type: str, data: Dict[str, Any]):
        """
        Broadcasts a JSON message to all active WebSocket clients in a case room.
        """
        if case_id not in self._case_rooms:
            return

        payload = {
            "event": event_type,
            "case_id": case_id,
            "data": data,
        }
        dead_connections = []
        for connection in list(self._case_rooms[case_id]):
            try:
                await connection.send_text(json.dumps(payload))
            except Exception as e:
                logger.warning(f"Error sending message to WebSocket client: {e}")
                dead_connections.append(connection)

        for dead in dead_connections:
            self.disconnect(case_id, dead)


ws_manager = ConnectionManager()
