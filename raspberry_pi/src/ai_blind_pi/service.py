"""Long-lived wearable assistance engine independent of phone lifetime."""

from __future__ import annotations

import asyncio
import logging
import subprocess
import time
from collections.abc import Awaitable, Callable
from pathlib import Path
from typing import Any

from .adapters.base import CameraAdapter, DetectorAdapter
from .feedback import FeedbackPolicy
from .latest_frame import LatestFrameBuffer
from .models import (
    AssistanceState,
    ComponentState,
    SettingsVersion,
    WearableSettings,
    now_iso,
    parse_utc_timestamp,
)
from .persistence import StateStore
from .protocol import ProtocolError

LOGGER = logging.getLogger(__name__)
EventSink = Callable[[str, dict[str, Any]], Awaitable[None]]


class AssistanceEngine:
    """Owns camera, inference, persisted settings and local speech.

    WebSocket clients are observers/controllers. They are deliberately not the
    owner of this object, so an active assistance pipeline continues when the
    phone disconnects.
    """

    def __init__(
        self,
        *,
        device_id: str,
        camera: CameraAdapter,
        detector: DetectorAdapter,
        feedback: FeedbackPolicy,
        store: StateStore,
        nms_threshold: float = 0.45,
        frame_stride: int = 2,
        max_camera_restarts: int = 3,
    ):
        self.device_id = device_id
        self.camera = camera
        self.detector = detector
        self.feedback = feedback
        self.store = store
        self.nms_threshold = nms_threshold
        self.frame_stride = frame_stride
        self.max_camera_restarts = max_camera_restarts
        try:
            self.settings = WearableSettings.from_storage(
                store.load().get("settings"), device_id=device_id
            )
        except (KeyError, TypeError, ValueError) as error:
            raise RuntimeError(f"persisted settings are invalid: {error}") from error
        self.state = AssistanceState.IDLE
        self.camera_state = ComponentState.UNAVAILABLE
        self.model_state = ComponentState.UNAVAILABLE
        self.last_error: dict[str, Any] | None = None
        self._frame_buffer = LatestFrameBuffer()
        self._capture_task: asyncio.Task[None] | None = None
        self._inference_task: asyncio.Task[None] | None = None
        self._event_sinks: set[EventSink] = set()
        self._state_lock = asyncio.Lock()
        self._phone_connections = 0
        self._started_at = time.monotonic()
        self._closing = False

    async def initialize(self) -> None:
        self.model_state = ComponentState.LOADING
        await self.emit("model_status", self.model_status_payload())
        try:
            await asyncio.to_thread(self.detector.load)
        except Exception as error:
            self.model_state = ComponentState.ERROR
            self.last_error = self._error_record("MODEL_LOAD_FAILED", str(error))
            LOGGER.exception("model initialization failed")
            await self.emit(
                "model_error",
                self.error_payload("MODEL_LOAD_FAILED", "The detection model could not be loaded."),
            )
            return
        self.model_state = ComponentState.READY
        # The camera is not claimed ready until a real start succeeds.
        self.camera_state = ComponentState.UNAVAILABLE
        await self.emit("model_status", self.model_status_payload())
        await self.emit("camera_status", self.camera_status_payload())

    def add_event_sink(self, sink: EventSink) -> None:
        self._event_sinks.add(sink)

    def remove_event_sink(self, sink: EventSink) -> None:
        self._event_sinks.discard(sink)

    async def emit(self, message_type: str, payload: dict[str, Any]) -> None:
        if not self._event_sinks:
            return
        results = await asyncio.gather(
            *(sink(message_type, payload) for sink in tuple(self._event_sinks)),
            return_exceptions=True,
        )
        for result in results:
            if isinstance(result, Exception):
                LOGGER.warning("event sink failed: %s", result)

    def set_phone_connections(self, count: int) -> None:
        self._phone_connections = max(0, count)

    @property
    def phone_connected(self) -> bool:
        return self._phone_connections > 0

    async def start(self) -> dict[str, Any]:
        async with self._state_lock:
            if self.state == AssistanceState.RUNNING:
                return self.status_payload()
            if self.state not in {AssistanceState.IDLE, AssistanceState.PAUSED}:
                raise ProtocolError("INVALID_STATE", "assistance cannot be started now")
            if self.model_state != ComponentState.READY:
                raise ProtocolError("MODEL_NOT_READY", "object-detection model is not ready")
            self.state = AssistanceState.STARTING
            await self.emit("device_status", self.status_payload())
            await self._start_pipeline()
            self.state = AssistanceState.RUNNING
            self.last_error = None
        await self.emit("device_status", self.status_payload())
        return self.status_payload()

    async def pause(self) -> dict[str, Any]:
        async with self._state_lock:
            if self.state == AssistanceState.PAUSED:
                return self.status_payload()
            if self.state != AssistanceState.RUNNING:
                raise ProtocolError("INVALID_STATE", "assistance is not running")
            await self._stop_pipeline(final_camera_state=ComponentState.PAUSED)
            self.state = AssistanceState.PAUSED
        await self.emit("device_status", self.status_payload())
        return self.status_payload()

    async def resume(self) -> dict[str, Any]:
        if self.state != AssistanceState.PAUSED:
            raise ProtocolError("INVALID_STATE", "assistance is not paused")
        return await self.start()

    async def stop(self) -> dict[str, Any]:
        async with self._state_lock:
            if self.state == AssistanceState.IDLE:
                return self.status_payload()
            self.state = AssistanceState.STOPPING
            await self.emit("device_status", self.status_payload())
            await self._stop_pipeline(final_camera_state=ComponentState.READY)
            self.state = AssistanceState.IDLE
        await self.emit("device_status", self.status_payload())
        return self.status_payload()

    async def _start_pipeline(self) -> None:
        self.camera_state = ComponentState.LOADING
        await self.emit("camera_status", self.camera_status_payload())
        try:
            await asyncio.to_thread(self.camera.start)
        except Exception as error:
            self.camera_state = ComponentState.ERROR
            self.state = AssistanceState.HARDWARE_ERROR
            self.last_error = self._error_record("CAMERA_START_FAILED", str(error))
            await self.emit(
                "camera_error",
                self.error_payload(
                    "CAMERA_START_FAILED", "The wearable camera could not start.", retryable=True
                ),
            )
            raise ProtocolError(
                "CAMERA_NOT_READY", "the wearable camera could not start", retryable=True
            ) from error
        self.camera_state = ComponentState.ACTIVE
        self._frame_buffer.clear()
        self._capture_task = asyncio.create_task(self._capture_loop(), name="camera-capture")
        self._inference_task = asyncio.create_task(self._inference_loop(), name="object-inference")
        await self.emit("camera_status", self.camera_status_payload())

    async def _stop_pipeline(self, *, final_camera_state: ComponentState) -> None:
        current = asyncio.current_task()
        tasks = [
            task
            for task in (self._capture_task, self._inference_task)
            if task is not None and task is not current
        ]
        self._capture_task = None
        self._inference_task = None
        for task in tasks:
            task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        try:
            await asyncio.to_thread(self.camera.stop)
        except Exception:
            LOGGER.exception("camera stop failed")
        self._frame_buffer.clear()
        self.camera_state = final_camera_state
        await self.emit("camera_status", self.camera_status_payload())

    async def _capture_loop(self) -> None:
        failures = 0
        while not self._closing:
            try:
                frame = await asyncio.to_thread(self.camera.capture)
                failures = 0
                self._frame_buffer.put_latest(frame)
            except asyncio.CancelledError:
                raise
            except Exception as error:
                failures += 1
                LOGGER.warning("camera capture failed (%d/%d)", failures, self.max_camera_restarts)
                if failures > self.max_camera_restarts:
                    self.state = AssistanceState.HARDWARE_ERROR
                    self.last_error = self._error_record("CAMERA_RECOVERY_EXHAUSTED", str(error))
                    await self._stop_pipeline(final_camera_state=ComponentState.ERROR)
                    await self.emit(
                        "camera_error",
                        self.error_payload(
                            "CAMERA_RECOVERY_EXHAUSTED",
                            "Camera recovery attempts were exhausted. "
                            "Check the CSI camera connection.",
                        ),
                    )
                    await self.emit("device_status", self.status_payload())
                    return
                self.camera_state = ComponentState.RECOVERING
                await self.emit("camera_status", self.camera_status_payload())
                await asyncio.to_thread(self.camera.stop)
                await asyncio.sleep(min(2 ** (failures - 1), 8))
                try:
                    await asyncio.to_thread(self.camera.start)
                    self.camera_state = ComponentState.ACTIVE
                    await self.emit("camera_status", self.camera_status_payload())
                except Exception:
                    LOGGER.warning("camera restart attempt failed", exc_info=True)

    async def _inference_loop(self) -> None:
        seen_frames = 0
        while not self._closing:
            frame = await self._frame_buffer.get()
            try:
                seen_frames += 1
                if seen_frames % self.frame_stride:
                    continue
                detections = list(
                    await asyncio.to_thread(
                        self.detector.detect,
                        frame,
                        confidence_threshold=self.settings.confidence_threshold,
                        nms_threshold=self.nms_threshold,
                    )
                )
                for detection in detections[:20]:
                    await self.emit(
                        "detection_event",
                        detection.as_payload(
                            source_device_id=self.device_id,
                            frame_sequence=frame.sequence,
                            timestamp=frame.captured_at_ms,
                        ),
                    )
                announced, target = await self.feedback.consider(
                    detections, self.settings, phone_connected=self.phone_connected
                )
                if announced is not None:
                    payload = announced.as_payload(
                        source_device_id=self.device_id,
                        frame_sequence=frame.sequence,
                        timestamp=frame.captured_at_ms,
                    )
                    payload.update(
                        {
                            "feedbackTarget": target,
                            "piAnnounced": target == "pi" and self.settings.speech_enabled,
                        }
                    )
                    await self.emit("priority_hazard_alert", payload)
            except asyncio.CancelledError:
                raise
            except Exception as error:
                LOGGER.exception("inference failed")
                self.model_state = ComponentState.ERROR
                self.state = AssistanceState.HARDWARE_ERROR
                self.last_error = self._error_record("INFERENCE_FAILED", str(error))
                await self._stop_pipeline(final_camera_state=ComponentState.READY)
                await self.emit(
                    "model_error",
                    self.error_payload("INFERENCE_FAILED", "Wearable inference failed."),
                )
                await self.emit("device_status", self.status_payload())
                return
            finally:
                self._frame_buffer.task_done()

    async def apply_settings(self, incoming: WearableSettings) -> WearableSettings:
        incoming.validate()
        ordering = _compare_settings_versions(incoming.version, self.settings.version)
        if ordering < 0 or (ordering == 0 and incoming.to_payload() != self.settings.to_payload()):
            raise ProtocolError(
                "SETTINGS_CONFLICT", "incoming settings are older than device settings"
            )
        if ordering == 0 and incoming.to_payload() == self.settings.to_payload():
            return self.settings
        self.settings = incoming
        await asyncio.to_thread(
            self.store.update,
            lambda state: state.__setitem__("settings", incoming.to_payload()),
        )
        return self.settings

    async def change_mode(self, mode: str) -> WearableSettings:
        if mode != "object_detection":
            raise ProtocolError("UNSUPPORTED_MODE", "only object_detection mode is supported")
        current = self.settings
        incoming = WearableSettings(
            version=SettingsVersion(
                revision=current.version.revision + 1,
                updated_at=now_iso(),
                source="pi",
                source_id=self.device_id,
            ),
            confidence_threshold=current.confidence_threshold,
            announcement_cooldown_seconds=current.announcement_cooldown_seconds,
            speech_enabled=current.speech_enabled,
            vibration_enabled=current.vibration_enabled,
            assistance_mode=mode,
        )
        return await self.apply_settings(incoming)

    def settings_payload(self) -> dict[str, Any]:
        return self.settings.to_payload()

    def status_payload(self) -> dict[str, Any]:
        return {
            "deviceId": self.device_id,
            "assistanceState": self.state.value,
            "assistanceMode": self.settings.assistance_mode,
            "settingsRevision": self.settings.version.revision,
            "updatedAt": now_iso(),
        }

    def camera_status_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"state": self.camera_state.value, "updatedAt": now_iso()}
        if self.last_error and self.last_error["code"].startswith("CAMERA"):
            payload.update(
                {"errorCode": self.last_error["code"], "message": "Wearable camera unavailable."}
            )
        return payload

    def model_status_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"state": self.model_state.value, "updatedAt": now_iso()}
        if self.last_error and self.last_error["code"] in {"MODEL_LOAD_FAILED", "INFERENCE_FAILED"}:
            payload.update(
                {"errorCode": self.last_error["code"], "message": "Wearable model unavailable."}
            )
        return payload

    @staticmethod
    def error_payload(code: str, message: str, *, retryable: bool = False) -> dict[str, Any]:
        return {"code": code, "message": message, "retryable": retryable}

    def health_payload(self) -> dict[str, Any]:
        memory_fraction = _memory_used_fraction()
        temperature = _cpu_temperature()
        throttled, under_voltage = _throttle_state()
        return {
            "deviceId": self.device_id,
            "uptimeSeconds": round(time.monotonic() - self._started_at),
            "memoryUsedFraction": memory_fraction,
            "cpuTemperatureCelsius": temperature,
            "throttled": throttled,
            "underVoltage": under_voltage,
            "cameraState": self.camera_state.value,
            "modelState": self.model_state.value,
            "measuredAt": now_iso(),
        }

    def _error_record(self, code: str, technical_message: str) -> dict[str, Any]:
        return {"code": code, "technicalMessage": technical_message, "timestamp": now_iso()}

    async def close(self) -> None:
        self._closing = True
        async with self._state_lock:
            await self._stop_pipeline(final_camera_state=ComponentState.UNAVAILABLE)
            self.state = AssistanceState.IDLE
        await self.feedback.close()
        await asyncio.to_thread(self.detector.close)


def _compare_settings_versions(first: SettingsVersion, second: SettingsVersion) -> int:
    if first.revision != second.revision:
        return 1 if first.revision > second.revision else -1
    first_time = parse_utc_timestamp(first.updated_at, "settings updatedAt")
    second_time = parse_utc_timestamp(second.updated_at, "settings updatedAt")
    if first_time != second_time:
        return 1 if first_time > second_time else -1
    source_rank = {"pi": 0, "phone": 1}
    if first.source != second.source:
        return 1 if source_rank[first.source] > source_rank[second.source] else -1
    if first.source_id == second.source_id:
        return 0
    return 1 if first.source_id > second.source_id else -1


def _memory_used_fraction() -> float:
    try:
        values: dict[str, int] = {}
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
            key, raw = line.split(":", 1)
            values[key] = int(raw.strip().split()[0])
        total = values["MemTotal"]
        available = values.get("MemAvailable", values.get("MemFree", 0))
        return round(max(0.0, min(1.0, (total - available) / total)), 5)
    except (OSError, KeyError, ValueError, ZeroDivisionError):
        return 0.0


def _cpu_temperature() -> float | None:
    try:
        return round(
            int(Path("/sys/class/thermal/thermal_zone0/temp").read_text().strip()) / 1000, 1
        )
    except (OSError, ValueError):
        return None


def _throttle_state() -> tuple[bool | None, bool | None]:
    try:
        completed = subprocess.run(
            ["vcgencmd", "get_throttled"],
            check=True,
            capture_output=True,
            text=True,
            timeout=1,
        )
        bits = int(completed.stdout.strip().split("=", 1)[1], 16)
        return bits != 0, bool(bits & ((1 << 0) | (1 << 16)))
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return None, None
