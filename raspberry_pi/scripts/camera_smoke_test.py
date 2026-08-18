#!/usr/bin/env python3
"""Run two independent, consecutive OV5647 capture sessions without storing frames."""

from __future__ import annotations

import argparse
import time


def run_session(session_number: int, frame_count: int) -> None:
    from picamera2 import Picamera2

    camera = Picamera2()
    try:
        configuration = camera.create_video_configuration(
            main={"size": (640, 480), "format": "RGB888"},
            controls={"FrameDurationLimits": (66_666, 66_666)},
            buffer_count=2,
            queue=False,
        )
        camera.configure(configuration)
        camera.start()
        started = time.monotonic()
        for index in range(frame_count):
            frame = camera.capture_array("main")
            if frame is None or frame.shape[:2] != (480, 640):
                raise RuntimeError(
                    f"session {session_number}, frame {index + 1}: invalid frame shape"
                )
        elapsed = time.monotonic() - started
        print(
            f"Session {session_number}: PASS, {frame_count} frames, "
            f"{frame_count / elapsed:.2f} capture FPS"
        )
    finally:
        try:
            camera.stop()
        finally:
            camera.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=int, default=30)
    args = parser.parse_args()
    if not 10 <= args.frames <= 300:
        raise SystemExit("--frames must be between 10 and 300")
    for session in (1, 2):
        run_session(session, args.frames)
        time.sleep(2)


if __name__ == "__main__":
    main()
