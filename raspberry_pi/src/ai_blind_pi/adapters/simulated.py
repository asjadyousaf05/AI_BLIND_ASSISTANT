"""Deterministic adapters for integration testing without Pi hardware."""

from __future__ import annotations

import time
from collections.abc import Sequence

import numpy as np

from ..models import BoundingBox, Detection, Frame, now_ms
from .base import CameraAdapter, DetectorAdapter, SpeechAdapter


class SimulatedCamera(CameraAdapter):
    def __init__(self, *, interval_seconds: float = 0.03):
        self.interval_seconds = interval_seconds
        self.started = False
        self.sequence = 0

    def start(self) -> None:
        self.started = True

    def capture(self) -> Frame:
        if not self.started:
            raise RuntimeError("simulated camera is not started")
        if self.interval_seconds:
            time.sleep(self.interval_seconds)
        self.sequence += 1
        pixels = np.zeros((240, 320, 3), dtype=np.uint8)
        return Frame(pixels, now_ms(), self.sequence, "rgb")

    def stop(self) -> None:
        self.started = False


class SimulatedDetector(DetectorAdapter):
    def __init__(self):
        self.loaded = False
        self.calls = 0

    @property
    def model_description(self) -> dict[str, object]:
        return {
            "runtime": "simulator",
            "inputSize": [320, 320],
            "classCount": 601,
            "outputShape": [605, 2100],
        }

    def load(self) -> None:
        self.loaded = True

    def detect(
        self, frame: Frame, *, confidence_threshold: float, nms_threshold: float
    ) -> Sequence[Detection]:
        if not self.loaded:
            raise RuntimeError("simulated detector is not loaded")
        self.calls += 1
        x_offset = ((frame.sequence % 9) - 4) * 0.01
        return [
            Detection(
                class_id=90,
                class_name="Car",
                confidence=max(confidence_threshold, 0.82),
                bounding_box=BoundingBox(0.28 + x_offset, 0.2, 0.74 + x_offset, 0.92),
                direction="center",
                priority=92,
                alert_category="mobility_hazard",
                relative_proximity="very_close",
            )
        ]

    def close(self) -> None:
        self.loaded = False


class RecordingSpeech(SpeechAdapter):
    def __init__(self):
        self.messages: list[tuple[str, bool]] = []

    async def speak(self, message: str, *, urgent: bool = False) -> None:
        self.messages.append((message, urgent))

    async def close(self) -> None:
        return


class NullSpeech(SpeechAdapter):
    async def speak(self, message: str, *, urgent: bool = False) -> None:
        return

    async def close(self) -> None:
        return
