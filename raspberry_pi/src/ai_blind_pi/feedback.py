"""Bounded, stability-gated local speech feedback."""

from __future__ import annotations

import asyncio
import logging
import shutil
import time
from collections import defaultdict, deque

from .adapters.base import SpeechAdapter
from .models import Detection, WearableSettings

LOGGER = logging.getLogger(__name__)


class EspeakSpeech(SpeechAdapter):
    """Single-slot espeak-ng output; urgent alerts may interrupt prior speech."""

    def __init__(self) -> None:
        if shutil.which("espeak-ng") is None:
            raise RuntimeError("espeak-ng is required when AIBA_ENABLE_LOCAL_SPEECH=true")
        self._process: asyncio.subprocess.Process | None = None

    async def speak(self, message: str, *, urgent: bool = False) -> None:
        if self._process and self._process.returncode is None:
            self._process.terminate()
            try:
                await asyncio.wait_for(self._process.wait(), timeout=0.5)
            except TimeoutError:
                self._process.kill()
                await self._process.wait()
        try:
            self._process = await asyncio.create_subprocess_exec(
                "espeak-ng",
                "-s",
                "165",
                message,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await self._process.wait()
        except FileNotFoundError:
            LOGGER.error("espeak-ng disappeared while the service was running")
        except asyncio.CancelledError:
            if self._process and self._process.returncode is None:
                self._process.terminate()
                try:
                    await asyncio.wait_for(self._process.wait(), timeout=0.5)
                except TimeoutError:
                    self._process.kill()
                    await self._process.wait()
            raise

    async def close(self) -> None:
        if self._process and self._process.returncode is None:
            self._process.terminate()
            try:
                await asyncio.wait_for(self._process.wait(), timeout=1)
            except TimeoutError:
                self._process.kill()
                await self._process.wait()
        self._process = None


class FeedbackPolicy:
    """Owns wearable feedback so assistance survives phone disconnection.

    The phone receives compact events for status only and never repeats a Pi
    alert. A bounded stability/cooldown policy prevents continuous speech.
    """

    def __init__(
        self,
        speech: SpeechAdapter,
        *,
        max_announcements_per_minute: int = 12,
        urgent_burst_allowance: int = 3,
    ):
        self.speech = speech
        self.max_announcements_per_minute = max_announcements_per_minute
        self.urgent_burst_allowance = urgent_burst_allowance
        self._stability: dict[tuple[int, str], int] = defaultdict(int)
        self._last_announced: dict[int, float] = {}
        self._announcement_times: deque[float] = deque()
        self._speech_task: asyncio.Task[None] | None = None

    async def consider(
        self,
        detections: list[Detection],
        settings: WearableSettings,
        *,
        phone_connected: bool,
    ) -> tuple[Detection | None, str]:
        _ = phone_connected
        active_keys = {(item.class_id, item.direction) for item in detections}
        for key in list(self._stability):
            if key not in active_keys:
                del self._stability[key]
        for key in active_keys:
            self._stability[key] += 1

        candidates = [
            item for item in detections if self._stability[(item.class_id, item.direction)] >= 2
        ]
        if not candidates:
            return None, "none"
        candidates.sort(
            key=lambda item: (
                item.priority,
                item.bounding_box.area,
                item.confidence,
            ),
            reverse=True,
        )
        now = time.monotonic()
        while self._announcement_times and now - self._announcement_times[0] >= 60:
            self._announcement_times.popleft()
        for candidate in candidates:
            urgent = candidate.priority >= 85
            cooldown = settings.announcement_cooldown_seconds * (0.5 if urgent else 1.0)
            if now - self._last_announced.get(candidate.class_id, -1e9) < cooldown:
                continue
            if len(self._announcement_times) >= self.max_announcements_per_minute and not urgent:
                continue
            if len(self._announcement_times) >= (
                self.max_announcements_per_minute + self.urgent_burst_allowance
            ):
                continue
            # The Pi always owns wearable feedback. phone_connected is retained
            # in this domain boundary for observability and future protocol
            # compatibility, but it never transfers alert ownership.
            target = "pi"
            if target == "pi" and settings.speech_enabled:
                message = self._message(candidate)
                if self._speech_task and not self._speech_task.done():
                    if urgent:
                        self._speech_task.cancel()
                        await asyncio.gather(self._speech_task, return_exceptions=True)
                    else:
                        continue
                self._speech_task = asyncio.create_task(
                    self.speech.speak(message, urgent=urgent),
                    name="local-speech",
                )
            self._last_announced[candidate.class_id] = now
            self._announcement_times.append(now)
            return candidate, target
        return None, "none"

    @staticmethod
    def _message(detection: Detection) -> str:
        suffix = "ahead" if detection.direction == "center" else f"on the {detection.direction}"
        close = " very close" if detection.relative_proximity == "very_close" else ""
        return f"{detection.class_name}{close} {suffix}"

    async def close(self) -> None:
        if self._speech_task:
            self._speech_task.cancel()
            await asyncio.gather(self._speech_task, return_exceptions=True)
            self._speech_task = None
        await self.speech.close()
