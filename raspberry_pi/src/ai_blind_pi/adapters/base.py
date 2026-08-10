"""Hardware boundaries used by the assistance engine."""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Sequence

from ..models import Detection, Frame


class CameraAdapter(ABC):
    @abstractmethod
    def start(self) -> None: ...

    @abstractmethod
    def capture(self) -> Frame: ...

    @abstractmethod
    def stop(self) -> None: ...


class DetectorAdapter(ABC):
    @property
    @abstractmethod
    def model_description(self) -> dict[str, object]: ...

    @abstractmethod
    def load(self) -> None: ...

    @abstractmethod
    def detect(
        self, frame: Frame, *, confidence_threshold: float, nms_threshold: float
    ) -> Sequence[Detection]: ...

    @abstractmethod
    def close(self) -> None: ...


class SpeechAdapter(ABC):
    @abstractmethod
    async def speak(self, message: str, *, urgent: bool = False) -> None: ...

    @abstractmethod
    async def close(self) -> None: ...
