"""Small, protected, atomic JSON state store."""

from __future__ import annotations

import fcntl
import json
import os
import tempfile
from pathlib import Path
from threading import RLock
from typing import Any

DEFAULT_STATE: dict[str, Any] = {
    "schemaVersion": 1,
    "pairingChallenge": None,
    "credentials": {},
    "settings": None,
    "lastHealth": None,
}


class StateStore:
    def __init__(self, path: Path):
        self.path = path
        self._lock = RLock()
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.path.parent.chmod(0o700)
        self._lock_path = self.path.with_suffix(".lock")
        self._lock_path.touch(mode=0o600, exist_ok=True)
        self._lock_path.chmod(0o600)
        if not self.path.exists():
            self.save(DEFAULT_STATE.copy())
        else:
            self.path.chmod(0o600)

    def load(self) -> dict[str, Any]:
        with self._lock:
            with self._interprocess_lock():
                return self._load_unlocked()

    def _load_unlocked(self) -> dict[str, Any]:
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise RuntimeError(f"cannot read protected state: {error}") from error
        if not isinstance(data, dict) or data.get("schemaVersion") != 1:
            raise RuntimeError("unsupported or corrupt state schema")
        merged = DEFAULT_STATE.copy()
        merged.update(data)
        return merged

    def save(self, state: dict[str, Any]) -> None:
        with self._lock:
            with self._interprocess_lock():
                self._save_unlocked(state)

    def _save_unlocked(self, state: dict[str, Any]) -> None:
        encoded = json.dumps(state, indent=2, sort_keys=True) + "\n"
        fd, temporary = tempfile.mkstemp(prefix=".state-", suffix=".json", dir=self.path.parent)
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, self.path)
            self.path.chmod(0o600)
        finally:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass

    def update(self, mutator: Any) -> dict[str, Any]:
        with self._lock:
            with self._interprocess_lock():
                state = self._load_unlocked()
                mutator(state)
                self._save_unlocked(state)
                return state

    def _interprocess_lock(self):
        return _FileLock(self._lock_path)


class _FileLock:
    def __init__(self, path: Path):
        self.path = path
        self._handle: Any = None

    def __enter__(self) -> _FileLock:
        self._handle = self.path.open("r+", encoding="utf-8")
        fcntl.flock(self._handle.fileno(), fcntl.LOCK_EX)
        return self

    def __exit__(self, *_: Any) -> None:
        if self._handle is not None:
            fcntl.flock(self._handle.fileno(), fcntl.LOCK_UN)
            self._handle.close()
            self._handle = None
