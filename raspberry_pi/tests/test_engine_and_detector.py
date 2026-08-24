from __future__ import annotations

import asyncio

import numpy as np
import pytest

from ai_blind_pi.adapters.detector_ncnn import (
    EXPECTED_CANDIDATES,
    EXPECTED_CLASSES,
    NcnnYoloDetector,
)
from ai_blind_pi.adapters.simulated import RecordingSpeech, SimulatedCamera, SimulatedDetector
from ai_blind_pi.feedback import FeedbackPolicy
from ai_blind_pi.latest_frame import LatestFrameBuffer
from ai_blind_pi.models import (
    AssistanceState,
    BoundingBox,
    Detection,
    Frame,
    SettingsVersion,
    WearableSettings,
    now_iso,
    now_ms,
)
from ai_blind_pi.persistence import StateStore
from ai_blind_pi.protocol import ProtocolError
from ai_blind_pi.service import AssistanceEngine


def test_latest_frame_buffer_discards_stale_frames() -> None:
    buffer = LatestFrameBuffer()
    first = Frame(None, now_ms(), 1)
    second = Frame(None, now_ms(), 2)
    buffer.put_latest(first)
    buffer.put_latest(second)
    assert buffer.dropped_frames == 1

    async def read() -> Frame:
        result = await buffer.get()
        buffer.task_done()
        return result

    assert asyncio.run(read()).sequence == 2


def test_ncnn_output_parser_uses_open_images_labels_and_nms(tmp_path) -> None:
    detector = NcnnYoloDetector(tmp_path)
    detector._labels = [f"Open Images class {index}" for index in range(EXPECTED_CLASSES)]
    detector._labels[90] = "Car"
    output = np.zeros((4 + EXPECTED_CLASSES, EXPECTED_CANDIDATES), dtype=np.float32)
    output[:4, 0] = [160, 176, 180, 250]
    output[4 + 90, 0] = 0.91
    output[:4, 1] = [161, 176, 178, 248]
    output[4 + 90, 1] = 0.83
    detections = detector.parse_output(
        output,
        confidence_threshold=0.45,
        nms_threshold=0.45,
        scale=1,
        pad_x=0,
        pad_y=0,
        source_width=320,
        source_height=320,
    )
    assert len(detections) == 1
    detection = detections[0]
    assert detection.class_id == 90
    assert detection.class_name == "Car"
    assert detection.direction == "center"
    assert detection.alert_category == "mobility_hazard"
    assert 0 <= detection.priority <= 100


@pytest.mark.asyncio
async def test_engine_state_settings_and_phone_independence(tmp_path) -> None:
    store = StateStore(tmp_path / "state.json")
    speech = RecordingSpeech()
    detector = SimulatedDetector()
    engine = AssistanceEngine(
        device_id="pi-test-device",
        camera=SimulatedCamera(interval_seconds=0.005),
        detector=detector,
        feedback=FeedbackPolicy(speech, max_announcements_per_minute=4),
        store=store,
        frame_stride=1,
    )
    await engine.initialize()
    await engine.start()
    await asyncio.sleep(0.08)
    assert engine.state == AssistanceState.RUNNING
    engine.set_phone_connections(0)
    await asyncio.sleep(0.03)
    assert engine.state == AssistanceState.RUNNING
    assert detector.calls > 0
    await engine.pause()
    assert engine.state == AssistanceState.PAUSED
    await engine.resume()

    incoming = WearableSettings(
        version=SettingsVersion(1, now_iso(), "phone", "phone-client"),
        confidence_threshold=0.55,
        announcement_cooldown_seconds=7,
        speech_enabled=True,
        vibration_enabled=False,
        assistance_mode="object_detection",
    )
    await engine.apply_settings(incoming)
    assert store.load()["settings"]["confidenceThreshold"] == 0.55
    conflicting = WearableSettings(
        version=incoming.version,
        confidence_threshold=0.65,
        announcement_cooldown_seconds=7,
        speech_enabled=True,
        vibration_enabled=False,
        assistance_mode="object_detection",
    )
    with pytest.raises(ProtocolError, match="older than device settings"):
        await engine.apply_settings(conflicting)
    await engine.stop()
    assert engine.state == AssistanceState.IDLE
    await engine.close()


class _FailingCamera(SimulatedCamera):
    def capture(self) -> Frame:
        raise RuntimeError("simulated CSI timeout")


@pytest.mark.asyncio
async def test_camera_recovery_is_bounded_and_reports_hardware_error(tmp_path) -> None:
    engine = AssistanceEngine(
        device_id="pi-camera-test",
        camera=_FailingCamera(interval_seconds=0),
        detector=SimulatedDetector(),
        feedback=FeedbackPolicy(RecordingSpeech()),
        store=StateStore(tmp_path / "state.json"),
        max_camera_restarts=1,
    )
    await engine.initialize()
    await engine.start()
    for _ in range(50):
        if engine.state == AssistanceState.HARDWARE_ERROR:
            break
        await asyncio.sleep(0.05)
    assert engine.state == AssistanceState.HARDWARE_ERROR
    assert engine.last_error["code"] == "CAMERA_RECOVERY_EXHAUSTED"
    await engine.close()


class _FailingDetector(SimulatedDetector):
    def detect(self, frame, *, confidence_threshold, nms_threshold):
        raise RuntimeError("simulated inference failure")


@pytest.mark.asyncio
async def test_inference_failure_stops_camera_pipeline(tmp_path) -> None:
    camera = SimulatedCamera(interval_seconds=0.001)
    engine = AssistanceEngine(
        device_id="pi-inference-test",
        camera=camera,
        detector=_FailingDetector(),
        feedback=FeedbackPolicy(RecordingSpeech()),
        store=StateStore(tmp_path / "state.json"),
        frame_stride=1,
    )
    await engine.initialize()
    await engine.start()
    for _ in range(50):
        if engine.state == AssistanceState.HARDWARE_ERROR:
            break
        await asyncio.sleep(0.01)
    assert engine.state == AssistanceState.HARDWARE_ERROR
    assert camera.started is False
    assert engine.last_error["code"] == "INFERENCE_FAILED"
    await engine.close()


@pytest.mark.asyncio
async def test_feedback_has_per_class_cooldown_and_phone_ownership() -> None:
    speech = RecordingSpeech()
    policy = FeedbackPolicy(speech, max_announcements_per_minute=2)
    settings = WearableSettings.defaults("pi-feedback-test")
    left = Detection(
        90,
        "Car",
        0.9,
        BoundingBox(0.05, 0.1, 0.45, 0.9),
        "left",
        70,
        "mobility_hazard",
    )
    center = Detection(
        90,
        "Car",
        0.9,
        BoundingBox(0.25, 0.1, 0.75, 0.9),
        "center",
        70,
        "mobility_hazard",
    )
    assert await policy.consider([left], settings, phone_connected=False) == (None, "none")
    announced, target = await policy.consider([left], settings, phone_connected=False)
    assert announced == left and target == "pi"
    await asyncio.sleep(0)
    await policy.consider([center], settings, phone_connected=False)
    assert await policy.consider([center], settings, phone_connected=False) == (None, "none")
    assert len(policy._announcement_times) == 1

    await policy.close()

    phone_speech = RecordingSpeech()
    phone_policy = FeedbackPolicy(phone_speech, max_announcements_per_minute=2)
    other = Detection(
        104,
        "Chair",
        0.8,
        BoundingBox(0.1, 0.1, 0.4, 0.8),
        "left",
        60,
        "mobility_hazard",
    )
    assert await phone_policy.consider([other], settings, phone_connected=True) == (
        None,
        "none",
    )
    announced, target = await phone_policy.consider([other], settings, phone_connected=True)
    assert announced == other and target == "phone"
    assert phone_speech.messages == []
    await phone_policy.close()
