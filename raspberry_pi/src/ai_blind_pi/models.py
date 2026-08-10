"""Hardware-neutral wearable service models and wire payloads."""

from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any


def now_ms() -> int:
    return time.time_ns() // 1_000_000


def now_iso() -> str:
    return datetime.now(UTC).isoformat(timespec="microseconds").replace("+00:00", "Z")


def parse_utc_timestamp(value: object, field_name: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError(f"{field_name} must be an ISO-8601 UTC timestamp")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as error:
        raise ValueError(f"{field_name} must be an ISO-8601 UTC timestamp") from error
    if parsed.tzinfo is None:
        raise ValueError(f"{field_name} must include UTC timezone information")
    return parsed.astimezone(UTC)


class AssistanceState(StrEnum):
    IDLE = "idle"
    STARTING = "starting"
    RUNNING = "running"
    PAUSED = "paused"
    STOPPING = "stopping"
    HARDWARE_ERROR = "hardware_error"


class ComponentState(StrEnum):
    UNAVAILABLE = "unavailable"
    LOADING = "loading"
    READY = "ready"
    ACTIVE = "active"
    PAUSED = "paused"
    RECOVERING = "recovering"
    ERROR = "error"


@dataclass(slots=True)
class Frame:
    pixels: Any
    captured_at_ms: int
    sequence: int
    color_space: str = "rgb"


@dataclass(frozen=True, slots=True)
class BoundingBox:
    x_min: float
    y_min: float
    x_max: float
    y_max: float

    @property
    def area(self) -> float:
        return max(0.0, self.x_max - self.x_min) * max(0.0, self.y_max - self.y_min)

    @property
    def center_x(self) -> float:
        return (self.x_min + self.x_max) / 2.0

    def as_payload(self) -> dict[str, float]:
        return {
            "left": round(self.x_min, 5),
            "top": round(self.y_min, 5),
            "right": round(self.x_max, 5),
            "bottom": round(self.y_max, 5),
        }


@dataclass(frozen=True, slots=True)
class Detection:
    class_id: int
    class_name: str
    confidence: float
    bounding_box: BoundingBox
    direction: str
    priority: int
    alert_category: str
    relative_proximity: str | None = None

    def as_payload(
        self,
        *,
        source_device_id: str,
        frame_sequence: int,
        timestamp: int,
    ) -> dict[str, Any]:
        captured_at = (
            datetime.fromtimestamp(timestamp / 1000, tz=UTC)
            .isoformat(timespec="milliseconds")
            .replace("+00:00", "Z")
        )
        return {
            "sourceDeviceId": source_device_id,
            "frameSequence": frame_sequence,
            "classId": self.class_id,
            "className": self.class_name,
            "confidence": round(self.confidence, 5),
            "boundingBox": self.bounding_box.as_payload(),
            "direction": self.direction,
            "capturedAt": captured_at,
            "priority": self.priority,
            "alertCategory": self.alert_category,
            "relativeProximity": self.relative_proximity,
        }


@dataclass(frozen=True, slots=True)
class SettingsVersion:
    revision: int
    updated_at: str
    source: str
    source_id: str

    def validate(self) -> None:
        if self.revision < 0:
            raise ValueError("settings revision must be non-negative")
        parse_utc_timestamp(self.updated_at, "settings updatedAt")
        if self.source not in {"phone", "pi"}:
            raise ValueError("settings source must be phone or pi")
        if not 1 <= len(self.source_id) <= 128:
            raise ValueError("settings sourceId is invalid")

    def to_payload(self) -> dict[str, Any]:
        return {
            "revision": self.revision,
            "updatedAt": self.updated_at,
            "source": self.source,
            "sourceId": self.source_id,
        }

    @classmethod
    def from_payload(cls, payload: object) -> SettingsVersion:
        if not isinstance(payload, dict) or set(payload) != {
            "revision",
            "updatedAt",
            "source",
            "sourceId",
        }:
            raise ValueError("settings version fields are invalid")
        if type(payload["revision"]) is not int:
            raise ValueError("settings revision must be an integer")
        version = cls(
            revision=payload["revision"],
            updated_at=str(payload["updatedAt"]),
            source=str(payload["source"]),
            source_id=str(payload["sourceId"]),
        )
        version.validate()
        return version


@dataclass(slots=True)
class WearableSettings:
    version: SettingsVersion
    confidence_threshold: float = 0.45
    announcement_cooldown_seconds: int = 5
    speech_enabled: bool = True
    vibration_enabled: bool = True
    assistance_mode: str = "object_detection"

    def validate(self) -> None:
        self.version.validate()
        if not 0.05 <= self.confidence_threshold <= 0.95:
            raise ValueError("confidenceThreshold must be between 0.05 and 0.95")
        if not 1 <= self.announcement_cooldown_seconds <= 300:
            raise ValueError("announcementCooldownSeconds must be between 1 and 300")
        if type(self.speech_enabled) is not bool:
            raise ValueError("speechEnabled must be a boolean")
        if type(self.vibration_enabled) is not bool:
            raise ValueError("vibrationEnabled must be a boolean")
        if self.assistance_mode != "object_detection":
            raise ValueError("only object_detection mode is supported")

    def to_payload(self) -> dict[str, Any]:
        return {
            "version": self.version.to_payload(),
            "confidenceThreshold": self.confidence_threshold,
            "announcementCooldownSeconds": self.announcement_cooldown_seconds,
            "speechEnabled": self.speech_enabled,
            "vibrationEnabled": self.vibration_enabled,
            "assistanceMode": self.assistance_mode,
        }

    @classmethod
    def defaults(cls, device_id: str) -> WearableSettings:
        return cls(
            version=SettingsVersion(
                revision=0,
                updated_at=now_iso(),
                source="pi",
                source_id=device_id,
            )
        )

    @classmethod
    def from_payload(cls, payload: object) -> WearableSettings:
        expected = {
            "version",
            "confidenceThreshold",
            "announcementCooldownSeconds",
            "speechEnabled",
            "vibrationEnabled",
            "assistanceMode",
        }
        if not isinstance(payload, dict) or set(payload) != expected:
            raise ValueError("wearable settings fields are invalid")
        confidence = payload["confidenceThreshold"]
        cooldown = payload["announcementCooldownSeconds"]
        if not isinstance(confidence, (int, float)) or isinstance(confidence, bool):
            raise ValueError("confidenceThreshold must be numeric")
        if type(cooldown) is not int:
            raise ValueError("announcementCooldownSeconds must be an integer")
        settings = cls(
            version=SettingsVersion.from_payload(payload["version"]),
            confidence_threshold=float(confidence),
            announcement_cooldown_seconds=cooldown,
            speech_enabled=payload["speechEnabled"],
            vibration_enabled=payload["vibrationEnabled"],
            assistance_mode=str(payload["assistanceMode"]),
        )
        settings.validate()
        return settings

    @classmethod
    def from_storage(cls, data: object, *, device_id: str) -> WearableSettings:
        return cls.defaults(device_id) if data is None else cls.from_payload(data)
