"""Strict wearable protocol v1 shared with the Flutter client."""

from __future__ import annotations

import hashlib
import hmac
import json
import math
import re
import uuid
from dataclasses import dataclass, replace
from typing import Any

from .models import now_iso, parse_utc_timestamp

PROTOCOL_VERSION = 1
MAX_MESSAGE_BYTES = 64 * 1024
MAX_CLOCK_SKEW_MS = 120_000

MESSAGE_TYPES = frozenset(
    {
        "hello",
        "authentication",
        "heartbeat",
        "device_status",
        "enrollment_request",
        "enrollment_result",
        "pair_request",
        "pair_result",
        "revoke_credential",
        "start_assistance",
        "pause_assistance",
        "resume_assistance",
        "stop_assistance",
        "change_mode",
        "update_settings",
        "request_current_settings",
        "synchronize_settings",
        "detection_event",
        "priority_hazard_alert",
        "camera_status",
        "camera_error",
        "model_status",
        "model_error",
        "device_health",
        "acknowledgement",
        "error",
        "graceful_disconnect",
    }
)

AUTHENTICATED_COMMANDS = frozenset(
    {
        "heartbeat",
        "revoke_credential",
        "start_assistance",
        "pause_assistance",
        "resume_assistance",
        "stop_assistance",
        "change_mode",
        "update_settings",
        "request_current_settings",
        "synchronize_settings",
        "graceful_disconnect",
    }
)

_MESSAGE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{7,127}$")
_AUTH_TAG = re.compile(r"^[0-9a-f]{64}$")


class ProtocolError(ValueError):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        related_message_id: str | None = None,
        retryable: bool = False,
    ):
        super().__init__(message)
        self.code = code
        self.related_message_id = related_message_id
        self.retryable = retryable


def timestamp_to_ms(value: str) -> int:
    parsed = parse_utc_timestamp(value, "timestamp")
    return int(parsed.timestamp() * 1000)


def _canonical_json(value: object) -> str:
    return json.dumps(
        value,
        separators=(",", ":"),
        sort_keys=True,
        ensure_ascii=False,
        allow_nan=False,
    )


def _length_prefixed(prefix: str, values: list[str]) -> str:
    result = prefix
    for value in values:
        result += f"|{len(value.encode('utf-8'))}:{value}"
    return result


@dataclass(frozen=True, slots=True)
class Envelope:
    type: str
    message_id: str
    timestamp: str
    sequence: int
    payload: dict[str, Any]
    protocol_version: int = PROTOCOL_VERSION
    authentication_tag: str | None = None

    def to_dict(self) -> dict[str, Any]:
        result = {
            "protocolVersion": self.protocol_version,
            "type": self.type,
            "messageId": self.message_id,
            "timestamp": self.timestamp,
            "sequence": self.sequence,
            "payload": self.payload,
        }
        if self.authentication_tag is not None:
            result["authenticationTag"] = self.authentication_tag
        return result

    def canonical_text(self, session_nonce: str) -> str:
        return _length_prefixed(
            "envelope-v1",
            [
                session_nonce,
                str(self.protocol_version),
                self.type,
                self.message_id,
                self.timestamp,
                str(self.sequence),
                _canonical_json(self.payload),
            ],
        )

    def signed(self, auth_key: bytes, *, session_nonce: str) -> Envelope:
        digest = hmac.new(
            auth_key,
            self.canonical_text(session_nonce).encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return replace(self, authentication_tag=digest)

    def verify_authentication_tag(self, auth_key: bytes, *, session_nonce: str) -> None:
        if not self.authentication_tag:
            raise ProtocolError(
                "AUTH_TAG_MISSING", "authenticated message has no authentication tag"
            )
        expected = self.signed(auth_key, session_nonce=session_nonce).authentication_tag
        if expected is None or not hmac.compare_digest(expected, self.authentication_tag):
            raise ProtocolError("AUTH_TAG_INVALID", "message authentication tag is invalid")

    def encode(self) -> str:
        return json.dumps(
            self.to_dict(), separators=(",", ":"), ensure_ascii=False, allow_nan=False
        )

    @classmethod
    def create(
        cls,
        message_type: str,
        payload: dict[str, Any] | None = None,
        *,
        sequence: int = 0,
        message_id: str | None = None,
        timestamp: str | None = None,
    ) -> Envelope:
        if message_type not in MESSAGE_TYPES:
            raise ProtocolError("UNSUPPORTED_MESSAGE", f"unsupported message type: {message_type}")
        return cls(
            type=message_type,
            message_id=message_id or uuid.uuid4().hex,
            timestamp=now_iso() if timestamp is None else timestamp,
            sequence=sequence,
            payload=payload or {},
        )

    @classmethod
    def decode(cls, raw: str | bytes) -> Envelope:
        byte_length = len(raw.encode("utf-8")) if isinstance(raw, str) else len(raw)
        if byte_length > MAX_MESSAGE_BYTES:
            raise ProtocolError("MESSAGE_TOO_LARGE", "message exceeds 64 KiB")
        try:
            data = json.loads(raw)
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise ProtocolError("MALFORMED_JSON", "message is not valid JSON") from error
        if not isinstance(data, dict):
            raise ProtocolError("INVALID_ENVELOPE", "message must be a JSON object")
        required = {
            "protocolVersion",
            "type",
            "messageId",
            "timestamp",
            "sequence",
            "payload",
        }
        missing = required - set(data)
        unknown = set(data) - (required | {"authenticationTag"})
        if missing or unknown:
            raise ProtocolError(
                "INVALID_ENVELOPE", "message has missing or unknown envelope fields"
            )
        if type(data["protocolVersion"]) is not int:
            raise ProtocolError("INVALID_ENVELOPE", "protocolVersion must be an integer")
        if data["protocolVersion"] != PROTOCOL_VERSION:
            raise ProtocolError(
                "UNSUPPORTED_PROTOCOL",
                f"protocol version {data['protocolVersion']} is not supported",
                related_message_id=str(data.get("messageId", "")) or None,
            )
        message_type = data["type"]
        if not isinstance(message_type, str) or message_type not in MESSAGE_TYPES:
            raise ProtocolError("UNSUPPORTED_MESSAGE", "unsupported message type")
        message_id = data["messageId"]
        if not isinstance(message_id, str) or not _MESSAGE_ID.fullmatch(message_id):
            raise ProtocolError("INVALID_ENVELOPE", "messageId has an invalid format")
        if not isinstance(data["timestamp"], str):
            raise ProtocolError("INVALID_ENVELOPE", "timestamp must be a string")
        try:
            parse_utc_timestamp(data["timestamp"], "timestamp")
        except ValueError as error:
            raise ProtocolError("INVALID_ENVELOPE", str(error)) from error
        if type(data["sequence"]) is not int or data["sequence"] < 0:
            raise ProtocolError("INVALID_ENVELOPE", "sequence must be a non-negative integer")
        if not isinstance(data["payload"], dict):
            raise ProtocolError("INVALID_PAYLOAD", "payload must be a JSON object")
        try:
            _validate_json_value(data["payload"], depth=0)
        except (TypeError, ValueError) as error:
            raise ProtocolError("INVALID_PAYLOAD", str(error)) from error
        authentication_tag = data.get("authenticationTag")
        if authentication_tag is not None and (
            not isinstance(authentication_tag, str) or not _AUTH_TAG.fullmatch(authentication_tag)
        ):
            raise ProtocolError("INVALID_ENVELOPE", "authenticationTag has an invalid format")
        return cls(
            type=message_type,
            message_id=message_id,
            timestamp=data["timestamp"],
            sequence=data["sequence"],
            payload=data["payload"],
            protocol_version=data["protocolVersion"],
            authentication_tag=authentication_tag,
        )


def _validate_json_value(value: object, *, depth: int) -> None:
    if depth > 16:
        raise ValueError("protocol payload nesting is too deep")
    if value is None or isinstance(value, (str, bool, int)):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("protocol numbers must be finite")
        return
    if isinstance(value, list):
        for item in value:
            _validate_json_value(item, depth=depth + 1)
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str) or not 1 <= len(key) <= 128:
                raise ValueError("protocol payload contains an invalid key")
            _validate_json_value(item, depth=depth + 1)
        return
    raise TypeError("protocol payload contains a non-JSON value")


def acknowledgement(
    command: Envelope, *, applied: bool = True, detail: str | None = None
) -> Envelope:
    payload: dict[str, Any] = {
        "requestMessageId": command.message_id,
        "applied": applied,
    }
    if detail:
        payload["detail"] = detail
    return Envelope.create("acknowledgement", payload)


def error_envelope(
    code: str,
    message: str,
    *,
    request_message_id: str | None = None,
    retryable: bool = False,
) -> Envelope:
    payload: dict[str, Any] = {
        "code": code,
        "message": message,
        "retryable": retryable,
    }
    if request_message_id:
        payload["requestMessageId"] = request_message_id
    return Envelope.create("error", payload)
