"""Authenticated, bounded WebSocket control plane for protocol v1."""

from __future__ import annotations

import asyncio
import logging
import secrets
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from typing import Any

from websockets.asyncio.server import Server, ServerConnection, serve
from websockets.exceptions import ConnectionClosed

from .config import ServiceConfig
from .models import WearableSettings
from .protocol import (
    AUTHENTICATED_COMMANDS,
    MAX_MESSAGE_BYTES,
    Envelope,
    ProtocolError,
    acknowledgement,
    error_envelope,
)
from .security import PairingManager, ReplayGuard
from .service import AssistanceEngine

LOGGER = logging.getLogger(__name__)
WEBSOCKET_PATH = "/wearable/v1"


@dataclass(eq=False, slots=True)
class ClientSession:
    connection: ServerConnection
    nonce: str
    authenticated: bool = False
    credential_id: str | None = None
    client_id: str | None = None
    auth_key: bytes | None = None
    provisional_auth_key: bytes | None = None
    last_sequence: int = -1
    last_seen_monotonic: float = field(default_factory=time.monotonic)
    outbound_sequence: int = 0
    queue: asyncio.Queue[Envelope] = field(default_factory=lambda: asyncio.Queue(maxsize=64))
    sender_task: asyncio.Task[None] | None = None

    def make_envelope(self, message_type: str, payload: dict[str, Any]) -> Envelope:
        envelope = Envelope.create(message_type, payload, sequence=self.outbound_sequence)
        self.outbound_sequence += 1
        signing_key = (
            self.auth_key
            if self.authenticated
            else (self.provisional_auth_key if message_type == "error" else None)
        )
        if signing_key is not None:
            if not self.authenticated and message_type != "error":
                raise RuntimeError("authenticated session has no key")
            envelope = envelope.signed(signing_key, session_nonce=self.nonce)
        return envelope

    def enqueue(self, message_type: str, payload: dict[str, Any]) -> bool:
        if self.queue.full() and message_type == "detection_event":
            return False
        if self.queue.full():
            try:
                self.queue.get_nowait()
                self.queue.task_done()
            except asyncio.QueueEmpty:
                pass
        self.queue.put_nowait(self.make_envelope(message_type, payload))
        return True


class IdempotencyCache:
    def __init__(self, *, max_entries: int = 2048, retention_seconds: int = 120):
        self.max_entries = max_entries
        self.retention_seconds = retention_seconds
        self._items: OrderedDict[tuple[str, str], tuple[float, str, dict[str, Any]]] = OrderedDict()

    def get(self, credential_id: str, message_id: str) -> tuple[str, dict[str, Any]] | None:
        self._prune()
        item = self._items.get((credential_id, message_id))
        if item is None:
            return None
        return item[1], item[2]

    def put(
        self,
        credential_id: str,
        message_id: str,
        response_type: str,
        payload: dict[str, Any],
    ) -> None:
        key = (credential_id, message_id)
        self._items[key] = (time.monotonic(), response_type, payload)
        self._items.move_to_end(key)
        self._prune()
        while len(self._items) > self.max_entries:
            self._items.popitem(last=False)

    def _prune(self) -> None:
        cutoff = time.monotonic() - self.retention_seconds
        while self._items and next(iter(self._items.values()))[0] < cutoff:
            self._items.popitem(last=False)


class WearableWebSocketServer:
    def __init__(
        self,
        *,
        config: ServiceConfig,
        engine: AssistanceEngine,
        pairing: PairingManager,
    ):
        self.config = config
        self.engine = engine
        self.pairing = pairing
        self._server: Server | None = None
        self._sessions: set[ClientSession] = set()
        self._authenticated_by_credential: dict[str, ClientSession] = {}
        self._command_replay = ReplayGuard(max_entries=8192, retention_ms=120_000)
        self._pairing_replay = ReplayGuard(max_entries=512, retention_ms=120_000)
        self._response_cache = IdempotencyCache()
        self._heartbeat_task: asyncio.Task[None] | None = None
        self._health_task: asyncio.Task[None] | None = None

    @property
    def bound_port(self) -> int:
        if self._server is None or not self._server.sockets:
            return self.config.port
        return int(self._server.sockets[0].getsockname()[1])

    async def start(self) -> None:
        self.engine.add_event_sink(self.broadcast)
        self._server = await serve(
            self._handle_connection,
            self.config.bind_host,
            self.config.port,
            max_size=MAX_MESSAGE_BYTES,
            max_queue=8,
            compression=None,
            ping_interval=None,
            close_timeout=3,
        )
        self._heartbeat_task = asyncio.create_task(
            self._heartbeat_loop(), name="websocket-heartbeat"
        )
        self._health_task = asyncio.create_task(self._health_loop(), name="device-health")
        LOGGER.info(
            "wearable WebSocket listening on %s:%s%s",
            self.config.bind_host,
            self.bound_port,
            WEBSOCKET_PATH,
        )

    async def close(self) -> None:
        self.engine.remove_event_sink(self.broadcast)
        tasks = [task for task in (self._heartbeat_task, self._health_task) if task]
        for task in tasks:
            task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._heartbeat_task = self._health_task = None
        for session in tuple(self._sessions):
            session.enqueue("graceful_disconnect", {"reason": "service_shutdown"})
            try:
                await asyncio.wait_for(session.queue.join(), timeout=1)
            except TimeoutError:
                pass
            await session.connection.close(code=1001, reason="service shutdown")
        if self._server:
            self._server.close()
            await self._server.wait_closed()
            self._server = None

    async def broadcast(self, message_type: str, payload: dict[str, Any]) -> None:
        for session in tuple(self._sessions):
            if session.authenticated:
                session.enqueue(message_type, payload)

    async def _handle_connection(self, connection: ServerConnection) -> None:
        path = getattr(getattr(connection, "request", None), "path", "")
        if path != WEBSOCKET_PATH:
            await connection.close(code=1008, reason="unsupported path")
            return
        session = ClientSession(connection=connection, nonce=secrets.token_urlsafe(32))
        self._sessions.add(session)
        session.sender_task = asyncio.create_task(
            self._sender_loop(session), name="websocket-sender"
        )
        credentials = self.pairing.store.load().get("credentials", {})
        session.enqueue(
            "hello",
            {
                "role": "pi",
                "deviceId": self.config.device_id,
                "deviceName": self.config.device_name,
                "supportedVersions": [1],
                "nonce": session.nonce,
                "serviceVersion": "0.1.0",
                "modelName": "YOLOv8n Open Images V7 NCNN 320",
                "paired": any(not item.get("revoked", False) for item in credentials.values()),
                "capabilities": [
                    "object_detection",
                    "local_speech",
                    "settings_sync",
                    "device_health",
                ],
            },
        )
        try:
            async for raw in connection:
                await self._handle_raw(session, raw)
        except ConnectionClosed:
            pass
        finally:
            await self._remove_session(session)

    async def _sender_loop(self, session: ClientSession) -> None:
        try:
            while True:
                envelope = await session.queue.get()
                try:
                    await session.connection.send(envelope.encode())
                finally:
                    session.queue.task_done()
        except (asyncio.CancelledError, ConnectionClosed):
            return

    async def _handle_raw(self, session: ClientSession, raw: str | bytes) -> None:
        request_id: str | None = None
        try:
            envelope = Envelope.decode(raw)
            request_id = envelope.message_id
            session.last_seen_monotonic = time.monotonic()
            if session.authenticated:
                await self._handle_authenticated(session, envelope)
            else:
                await self._handle_unauthenticated(session, envelope)
        except ProtocolError as error:
            session.enqueue(
                "error",
                error_envelope(
                    error.code,
                    str(error),
                    request_message_id=error.related_message_id or request_id,
                    retryable=error.retryable,
                ).payload,
            )
        except (KeyError, TypeError, ValueError) as error:
            session.enqueue(
                "error",
                error_envelope(
                    "INVALID_PAYLOAD", str(error), request_message_id=request_id
                ).payload,
            )
        except Exception:
            LOGGER.exception("unexpected client-message failure")
            session.enqueue(
                "error",
                error_envelope(
                    "INTERNAL_ERROR",
                    "command could not be processed",
                    request_message_id=request_id,
                    retryable=True,
                ).payload,
            )

    async def _handle_unauthenticated(self, session: ClientSession, envelope: Envelope) -> None:
        if envelope.type == "pair_request":
            if envelope.authentication_tag is not None:
                raise ProtocolError("AUTH_TAG_UNEXPECTED", "pairing request must be unsigned")
            self._pairing_replay.check_and_mark(envelope.message_id, envelope.timestamp)
            self._require_fields(envelope.payload, {"clientId", "clientName", "pairingCode"})
            client_id = str(envelope.payload["clientId"])
            display_name = str(envelope.payload["clientName"])
            code = str(envelope.payload["pairingCode"])
            if not 1 <= len(client_id) <= 128 or not 1 <= len(display_name) <= 80:
                raise ProtocolError("INVALID_PAYLOAD", "client identity is invalid")
            try:
                credential_id, token = await asyncio.to_thread(
                    self.pairing.consume_code,
                    code,
                    client_id=client_id,
                    display_name=display_name,
                )
                payload = {
                    "requestMessageId": envelope.message_id,
                    "paired": True,
                    "deviceId": self.config.device_id,
                    "credentialId": credential_id,
                    "credentialSecret": token,
                }
            except ProtocolError as error:
                payload = {
                    "requestMessageId": envelope.message_id,
                    "paired": False,
                    "errorCode": error.code.lower(),
                }
            session.enqueue("pair_result", payload)
            return
        if envelope.type != "authentication":
            raise ProtocolError("AUTH_REQUIRED", "authenticate or pair before sending commands")
        credential_id_value = envelope.payload.get("credentialId")
        if isinstance(credential_id_value, str):
            provisional_key = await asyncio.to_thread(
                self.pairing.credential_key, credential_id_value
            )
            if provisional_key is not None:
                envelope.verify_authentication_tag(provisional_key, session_nonce=session.nonce)
                session.provisional_auth_key = provisional_key
        credential_id, auth_key = await asyncio.to_thread(
            self.pairing.authenticate,
            envelope,
            expected_nonce=session.nonce,
            replay_guard=self._command_replay,
        )
        envelope.verify_authentication_tag(auth_key, session_nonce=session.nonce)
        existing = self._authenticated_by_credential.get(credential_id)
        if existing is not None and existing is not session:
            existing.enqueue("graceful_disconnect", {"reason": "superseded_connection"})
            await existing.connection.close(code=1000, reason="superseded")
        session.authenticated = True
        session.credential_id = credential_id
        session.client_id = str(envelope.payload["clientId"])
        session.auth_key = auth_key
        session.provisional_auth_key = None
        session.last_sequence = envelope.sequence
        self._authenticated_by_credential[credential_id] = session
        self._update_phone_count()
        session.enqueue("acknowledgement", acknowledgement(envelope).payload)

    async def _handle_authenticated(self, session: ClientSession, envelope: Envelope) -> None:
        if session.auth_key is None or session.credential_id is None:
            raise ProtocolError("AUTH_REQUIRED", "authenticated session is incomplete")
        envelope.verify_authentication_tag(session.auth_key, session_nonce=session.nonce)
        cached = self._response_cache.get(session.credential_id, envelope.message_id)
        if cached is not None:
            session.enqueue(*cached)
            return
        self._command_replay.check_and_mark(envelope.message_id, envelope.timestamp)
        if envelope.sequence <= session.last_sequence:
            raise ProtocolError("OUT_OF_ORDER", "message sequence is not increasing")
        session.last_sequence = envelope.sequence
        if envelope.type not in AUTHENTICATED_COMMANDS:
            raise ProtocolError("UNSUPPORTED_MESSAGE", "message is not a client command")

        if envelope.type == "heartbeat":
            self._require_fields(envelope.payload, {"kind"}, optional={"replyTo"})
            kind = envelope.payload["kind"]
            if kind == "ping":
                session.enqueue("heartbeat", {"kind": "pong", "replyTo": envelope.message_id})
            elif kind != "pong":
                raise ProtocolError("INVALID_PAYLOAD", "heartbeat kind must be ping or pong")
            return

        response = acknowledgement(envelope).payload
        should_close = False
        if envelope.type == "start_assistance":
            self._require_fields(envelope.payload, set())
            await self.engine.start()
        elif envelope.type == "pause_assistance":
            self._require_fields(envelope.payload, set())
            await self.engine.pause()
        elif envelope.type == "resume_assistance":
            self._require_fields(envelope.payload, set())
            await self.engine.resume()
        elif envelope.type == "stop_assistance":
            self._require_fields(envelope.payload, set())
            await self.engine.stop()
        elif envelope.type == "change_mode":
            self._require_fields(envelope.payload, {"mode"})
            settings = await self.engine.change_mode(str(envelope.payload["mode"]))
            await self.broadcast("synchronize_settings", settings.to_payload())
        elif envelope.type in {"update_settings", "synchronize_settings"}:
            incoming = WearableSettings.from_payload(envelope.payload)
            settings = await self.engine.apply_settings(incoming)
            await self.broadcast("synchronize_settings", settings.to_payload())
        elif envelope.type == "request_current_settings":
            self._require_fields(envelope.payload, set())
            session.enqueue("synchronize_settings", self.engine.settings_payload())
            session.enqueue("device_status", self.engine.status_payload())
            session.enqueue("camera_status", self.engine.camera_status_payload())
            session.enqueue("model_status", self.engine.model_status_payload())
            session.enqueue("device_health", self.engine.health_payload())
        elif envelope.type == "revoke_credential":
            self._require_fields(envelope.payload, {"credentialId"})
            requested = str(envelope.payload["credentialId"])
            if requested != session.credential_id:
                raise ProtocolError(
                    "AUTH_CREDENTIAL_INVALID", "only the active credential can be revoked"
                )
            if not await asyncio.to_thread(self.pairing.revoke, requested):
                raise ProtocolError("AUTH_CREDENTIAL_INVALID", "credential does not exist")
            should_close = True
        elif envelope.type == "graceful_disconnect":
            self._require_fields(envelope.payload, {"reason"})
            should_close = True
        else:
            raise ProtocolError("UNSUPPORTED_MESSAGE", "unsupported client command")

        self._response_cache.put(
            session.credential_id, envelope.message_id, "acknowledgement", response
        )
        session.enqueue("acknowledgement", response)
        if should_close:
            try:
                await asyncio.wait_for(session.queue.join(), timeout=1)
            except TimeoutError:
                pass
            await session.connection.close(code=1000, reason="client disconnect")

    @staticmethod
    def _require_fields(
        payload: dict[str, Any], expected: set[str], *, optional: set[str] | None = None
    ) -> None:
        allowed = expected | (optional or set())
        if not expected.issubset(payload) or set(payload) - allowed:
            raise ProtocolError(
                "INVALID_PAYLOAD",
                "payload fields are invalid; expected " + ", ".join(sorted(expected)),
            )

    async def _remove_session(self, session: ClientSession) -> None:
        self._sessions.discard(session)
        if (
            session.credential_id
            and self._authenticated_by_credential.get(session.credential_id) is session
        ):
            del self._authenticated_by_credential[session.credential_id]
        if session.sender_task:
            session.sender_task.cancel()
            await asyncio.gather(session.sender_task, return_exceptions=True)
        self._update_phone_count()

    def _update_phone_count(self) -> None:
        self.engine.set_phone_connections(
            sum(1 for session in self._sessions if session.authenticated)
        )

    async def _heartbeat_loop(self) -> None:
        while True:
            await asyncio.sleep(self.config.heartbeat_seconds)
            now = time.monotonic()
            for session in tuple(self._sessions):
                if now - session.last_seen_monotonic > self.config.stale_seconds:
                    await session.connection.close(code=1001, reason="heartbeat timeout")
                elif session.authenticated:
                    session.enqueue("heartbeat", {"kind": "ping"})

    async def _health_loop(self) -> None:
        while True:
            await asyncio.sleep(15)
            await self.broadcast("device_health", self.engine.health_payload())
