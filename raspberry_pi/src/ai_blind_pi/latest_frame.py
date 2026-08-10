"""A one-slot asynchronous frame buffer that drops stale camera frames."""

from __future__ import annotations

import asyncio

from .models import Frame


class LatestFrameBuffer:
    def __init__(self) -> None:
        self._queue: asyncio.Queue[Frame] = asyncio.Queue(maxsize=1)
        self.dropped_frames = 0

    def put_latest(self, frame: Frame) -> None:
        if self._queue.full():
            try:
                self._queue.get_nowait()
                self._queue.task_done()
                self.dropped_frames += 1
            except asyncio.QueueEmpty:
                pass
        self._queue.put_nowait(frame)

    async def get(self) -> Frame:
        return await self._queue.get()

    def task_done(self) -> None:
        self._queue.task_done()

    def clear(self) -> None:
        while True:
            try:
                self._queue.get_nowait()
                self._queue.task_done()
            except asyncio.QueueEmpty:
                return
