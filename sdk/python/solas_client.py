"""
Solas Real-Time WebRTC Media Engine - Python Client SDK
High-performance asynchronous client library for WebRTC signaling, WHIP ingestion,
and automated conference management.
"""

import asyncio
import json
import logging
import urllib.request
import urllib.error
from typing import Callable, Dict, List, Optional, Any

logger = logging.getLogger("solas_sdk")


class SolasError(Exception):
    """Base exception for all Solas SDK client errors."""
    pass


class SdpNegotiationError(SolasError):
    """Raised when SDP exchange or parsing fails."""
    pass


class TrackInfo:
    """Represents a remote or local WebRTC media track."""

    def __init__(self, track_id: str, kind: str, ssrc: int, simulcast: bool = False):
        self.track_id = track_id
        self.kind = kind
        self.ssrc = ssrc
        self.simulcast = simulcast
        self.current_layer = "high"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "track_id": self.track_id,
            "kind": self.kind,
            "ssrc": self.ssrc,
            "simulcast": self.simulcast,
        }


class SolasClient:
    """
    Asynchronous client for interacting with Solas SFU instances via
    WebSocket JSON-RPC 2.0 and HTTP REST/WHIP endpoints.
    """

    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url.rstrip("/")
        self.ws_url = self.base_url.replace("http://", "ws://").replace("https://", "wss://") + "/ws"
        self.room_id: Optional[str] = None
        self.peer_id: Optional[str] = None
        self.display_name: str = ""
        self.is_connected: bool = False
        self._msg_id: int = 1
        self._pending_responses: Dict[int, asyncio.Future] = {}

        # Callback registry
        self._event_handlers: Dict[str, List[Callable]] = {
            "peer_joined": [],
            "peer_left": [],
            "track_published": [],
            "active_speaker_changed": [],
            "layer_switched": [],
        }

    def on(self, event_name: str, handler: Optional[Callable] = None):
        """Register an event handler or use as a decorator."""
        if handler is not None:
            if event_name in self._event_handlers:
                self._event_handlers[event_name].append(handler)
            else:
                raise SolasError(f"Unknown event name: {event_name}")
            return handler

        def decorator(fn: Callable) -> Callable:
            if event_name in self._event_handlers:
                self._event_handlers[event_name].append(fn)
            else:
                raise SolasError(f"Unknown event name: {event_name}")
            return fn
        return decorator

    def _emit(self, event_name: str, *args, **kwargs) -> None:
        """Dispatch an event to all registered handlers."""
        if event_name in self._event_handlers:
            for handler in self._event_handlers[event_name]:
                try:
                    handler(*args, **kwargs)
                except Exception as e:
                    logger.error(f"Error in handler for {event_name}: {e}")

    # -------------------------------------------------------------------------
    # HTTP REST & WHIP / WHEP Endpoints
    # -------------------------------------------------------------------------

    def check_health(self) -> bool:
        """Synchronously check health of the Solas server."""
        try:
            req = urllib.request.Request(f"{self.base_url}/health")
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                return resp.status == 200
        except Exception as e:
            logger.warning(f"Health check failed: {e}")
            return False

    def get_status(self) -> Dict[str, Any]:
        """Fetch server runtime capabilities, active rooms, and supported codecs."""
        req = urllib.request.Request(f"{self.base_url}/api/v1/status")
        try:
            with urllib.request.urlopen(req, timeout=5.0) as resp:
                data = resp.read().decode("utf-8")
                return json.loads(data)
        except urllib.error.URLError as e:
            raise SolasError(f"Failed to fetch status: {e}")

    def whip_publish(self, sdp_offer: str, endpoint: str = "/api/v1/whip") -> str:
        """
        Publish a stream using RFC 9724 WebRTC HTTP Ingestion Protocol (WHIP).
        Returns the answer SDP from the Solas SFU.
        """
        url = f"{self.base_url}{endpoint}"
        req = urllib.request.Request(
            url,
            data=sdp_offer.encode("utf-8"),
            headers={"Content-Type": "application/sdp"},
            method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=10.0) as resp:
                if resp.status not in (200, 201):
                    raise SdpNegotiationError(f"WHIP server returned status {resp.status}")
                return resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            raise SdpNegotiationError(f"WHIP request failed: {e.code} - {e.reason}")

    def whep_subscribe(self, sdp_offer: str, endpoint: str = "/api/v1/whep") -> str:
        """
        Subscribe to an egress stream using WHEP.
        Returns the answer SDP from the Solas SFU.
        """
        url = f"{self.base_url}{endpoint}"
        req = urllib.request.Request(
            url,
            data=sdp_offer.encode("utf-8"),
            headers={"Content-Type": "application/sdp"},
            method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=10.0) as resp:
                if resp.status not in (200, 201):
                    raise SdpNegotiationError(f"WHEP server returned status {resp.status}")
                return resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            raise SdpNegotiationError(f"WHEP request failed: {e.code} - {e.reason}")

    # -------------------------------------------------------------------------
    # JSON-RPC Message Formatter
    # -------------------------------------------------------------------------

    def create_rpc_request(self, method: str, params: Dict[str, Any]) -> str:
        """Construct a standardized JSON-RPC 2.0 request payload."""
        req_id = self._msg_id
        self._msg_id += 1
        payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": method,
            "params": params
        }
        return json.dumps(payload)

    def handle_incoming_message(self, raw_json: str) -> None:
        """Process incoming JSON-RPC response or notification frame."""
        try:
            msg = json.loads(raw_json)
        except json.JSONDecodeError as e:
            logger.error(f"Malformed JSON frame received: {e}")
            return

        # Handle Responses
        if "id" in msg and msg["id"] in self._pending_responses:
            fut = self._pending_responses.pop(msg["id"])
            if "error" in msg:
                fut.set_exception(SolasError(msg["error"].get("message", "RPC Error")))
            else:
                fut.set_result(msg.get("result", {}))
            return

        # Handle Server-Initiated Notifications
        if "method" in msg:
            method = msg["method"]
            params = msg.get("params", {})
            self._emit(method, params)
