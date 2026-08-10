"""OV5647/libcamera capture adapter using Picamera2.

Picamera2 is imported only on hardware so development and simulation remain
portable. RGB888 libcamera buffers are byte-ordered BGR on little-endian hosts;
the frame advertises that fact so the detector performs the correct conversion.
"""

from __future__ import annotations

from typing import Any

from ..models import Frame, now_ms
from .base import CameraAdapter


class Picamera2Camera(CameraAdapter):
    def __init__(self, *, width: int, height: int, fps: int):
        self.width = width
        self.height = height
        self.fps = fps
        self._camera: Any = None
        self._sequence = 0

    def start(self) -> None:
        if self._camera is not None:
            return
        try:
            from picamera2 import Picamera2
        except ImportError as error:
            raise RuntimeError(
                "Picamera2 is unavailable; install the Debian python3-picamera2 package"
            ) from error
        camera = Picamera2()
        try:
            frame_duration = int(1_000_000 / self.fps)
            configuration = camera.create_video_configuration(
                main={"size": (self.width, self.height), "format": "RGB888"},
                controls={"FrameDurationLimits": (frame_duration, frame_duration)},
                buffer_count=2,
                queue=False,
            )
            camera.configure(configuration)
            camera.start()
            self._camera = camera
        except Exception:
            try:
                camera.close()
            except Exception:
                pass
            raise

    def capture(self) -> Frame:
        if self._camera is None:
            raise RuntimeError("camera is not started")
        pixels = self._camera.capture_array("main")
        if pixels is None or getattr(pixels, "ndim", 0) != 3 or pixels.shape[2] < 3:
            raise RuntimeError("camera returned an invalid frame")
        self._sequence += 1
        return Frame(
            pixels=pixels[:, :, :3],
            captured_at_ms=now_ms(),
            sequence=self._sequence,
            color_space="bgr",
        )

    def stop(self) -> None:
        camera, self._camera = self._camera, None
        if camera is None:
            return
        try:
            camera.stop()
        finally:
            camera.close()
