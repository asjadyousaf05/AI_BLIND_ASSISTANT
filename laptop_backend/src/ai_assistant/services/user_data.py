"""Per-user data services: memory, reminders, notes, schedule, preferences, audit."""

from __future__ import annotations

import logging
import sqlite3
import uuid
from datetime import UTC, datetime

from ..config import settings

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


# ---------------------------------------------------------------------------
# Memory service
# ---------------------------------------------------------------------------


class MemoryService:
    """Manages user memory — explicitly saved facts only."""

    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def save(self, user_id: str, content: str) -> str:
        memory_id = str(uuid.uuid4())
        with self._conn:
            self._conn.execute(
                "INSERT INTO memories (id, user_id, content, source) VALUES (?, ?, ?, 'explicit')",
                (memory_id, user_id, content[:1024]),
            )
        return memory_id

    def list(self, user_id: str, limit: int = 20) -> list[dict]:
        rows = self._conn.execute(
            "SELECT id, content, created_at FROM memories WHERE user_id = ? ORDER BY created_at DESC LIMIT ?",
            (user_id, limit),
        ).fetchall()
        return [dict(r) for r in rows]

    def forget(self, user_id: str, memory_id: str) -> bool:
        with self._conn:
            result = self._conn.execute(
                "DELETE FROM memories WHERE id = ? AND user_id = ?",
                (memory_id, user_id),
            )
        return result.rowcount > 0

    def get_context(self, user_id: str, limit: int = 5) -> str:
        """Return a bounded string summary for prompt injection."""
        rows = self.list(user_id, limit=limit)
        if not rows:
            return ""
        lines = [f"- {r['content']}" for r in rows]
        return "Saved memories:\n" + "\n".join(lines)


# ---------------------------------------------------------------------------
# Reminder service
# ---------------------------------------------------------------------------


class ReminderService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def create(
        self,
        user_id: str,
        title: str,
        scheduled_at: str,
        note: str | None = None,
        timezone_str: str = "UTC",
    ) -> dict:
        rid = str(uuid.uuid4())
        now = _now_iso()
        with self._conn:
            self._conn.execute(
                """INSERT INTO reminders
                   (id, user_id, title, note, scheduled_at, timezone, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (rid, user_id, title[:256], note, scheduled_at, timezone_str, now, now),
            )
        return {"id": rid, "title": title, "scheduled_at": scheduled_at}

    def list(self, user_id: str, include_completed: bool = False) -> list[dict]:
        query = "SELECT * FROM reminders WHERE user_id = ?"
        params: list = [user_id]
        if not include_completed:
            query += " AND completed = 0"
        query += " ORDER BY scheduled_at ASC LIMIT 50"
        rows = self._conn.execute(query, params).fetchall()
        return [dict(r) for r in rows]

    def complete(self, user_id: str, reminder_id: str) -> bool:
        with self._conn:
            result = self._conn.execute(
                "UPDATE reminders SET completed = 1, updated_at = ? WHERE id = ? AND user_id = ?",
                (_now_iso(), reminder_id, user_id),
            )
        return result.rowcount > 0

    def delete(self, user_id: str, reminder_id: str) -> bool:
        with self._conn:
            result = self._conn.execute(
                "DELETE FROM reminders WHERE id = ? AND user_id = ?",
                (reminder_id, user_id),
            )
        return result.rowcount > 0


# ---------------------------------------------------------------------------
# Note service
# ---------------------------------------------------------------------------


class NoteService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def save(self, user_id: str, title: str, content: str) -> str:
        nid = str(uuid.uuid4())
        now = _now_iso()
        with self._conn:
            self._conn.execute(
                "INSERT INTO notes (id, user_id, title, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                (nid, user_id, title[:256], content[:4096], now, now),
            )
        return nid

    def list(self, user_id: str) -> list[dict]:
        rows = self._conn.execute(
            "SELECT id, title, content, created_at FROM notes WHERE user_id = ? ORDER BY created_at DESC LIMIT 50",
            (user_id,),
        ).fetchall()
        return [dict(r) for r in rows]

    def read(self, user_id: str, note_id: str) -> dict | None:
        row = self._conn.execute(
            "SELECT * FROM notes WHERE id = ? AND user_id = ?",
            (note_id, user_id),
        ).fetchone()
        return dict(row) if row else None

    def delete(self, user_id: str, note_id: str) -> bool:
        with self._conn:
            result = self._conn.execute(
                "DELETE FROM notes WHERE id = ? AND user_id = ?",
                (note_id, user_id),
            )
        return result.rowcount > 0


# ---------------------------------------------------------------------------
# Schedule service
# ---------------------------------------------------------------------------


class ScheduleService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def create(
        self,
        user_id: str,
        title: str,
        starts_at: str,
        ends_at: str | None = None,
        description: str | None = None,
        timezone_str: str = "UTC",
    ) -> str:
        eid = str(uuid.uuid4())
        now = _now_iso()
        with self._conn:
            self._conn.execute(
                """INSERT INTO schedule_entries
                   (id, user_id, title, starts_at, ends_at, timezone, description, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    eid,
                    user_id,
                    title[:256],
                    starts_at,
                    ends_at,
                    timezone_str,
                    description,
                    now,
                    now,
                ),
            )
        return eid

    def list(self, user_id: str) -> list[dict]:
        rows = self._conn.execute(
            "SELECT * FROM schedule_entries WHERE user_id = ? ORDER BY starts_at ASC LIMIT 50",
            (user_id,),
        ).fetchall()
        return [dict(r) for r in rows]

    def delete(self, user_id: str, entry_id: str) -> bool:
        with self._conn:
            result = self._conn.execute(
                "DELETE FROM schedule_entries WHERE id = ? AND user_id = ?",
                (entry_id, user_id),
            )
        return result.rowcount > 0


# ---------------------------------------------------------------------------
# Preference service
# ---------------------------------------------------------------------------


class PreferenceService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def save(self, user_id: str, key: str, value: str) -> None:
        with self._conn:
            self._conn.execute(
                "INSERT OR REPLACE INTO preferences (user_id, key, value, updated_at) VALUES (?, ?, ?, ?)",
                (user_id, key[:64], value[:512], _now_iso()),
            )

    def get(self, user_id: str, key: str) -> str | None:
        row = self._conn.execute(
            "SELECT value FROM preferences WHERE user_id = ? AND key = ?",
            (user_id, key),
        ).fetchone()
        return row["value"] if row else None

    def get_all(self, user_id: str) -> dict[str, str]:
        rows = self._conn.execute(
            "SELECT key, value FROM preferences WHERE user_id = ?",
            (user_id,),
        ).fetchall()
        return {r["key"]: r["value"] for r in rows}


# ---------------------------------------------------------------------------
# Conversation service
# ---------------------------------------------------------------------------


class ConversationService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn
        self._max_rows = 200  # Per-user bounded conversation

    def append(
        self,
        user_id: str,
        role: str,
        content: str,
        tool_name: str | None = None,
    ) -> str:
        mid = str(uuid.uuid4())
        with self._conn:
            self._conn.execute(
                "INSERT INTO conversations (id, user_id, role, content, tool_name) VALUES (?, ?, ?, ?, ?)",
                (mid, user_id, role, content[:4096], tool_name),
            )
        self._prune(user_id)
        return mid

    def _prune(self, user_id: str) -> None:
        count = self._conn.execute(
            "SELECT COUNT(*) FROM conversations WHERE user_id = ?",
            (user_id,),
        ).fetchone()[0]
        if count > self._max_rows:
            excess = count - self._max_rows
            self._conn.execute(
                """DELETE FROM conversations WHERE id IN (
                   SELECT id FROM conversations WHERE user_id = ?
                   ORDER BY created_at ASC LIMIT ?
                )""",
                (user_id, excess),
            )

    def list(self, user_id: str, limit: int = 20) -> list[dict]:
        rows = self._conn.execute(
            """SELECT id, role, content, tool_name, created_at
               FROM conversations WHERE user_id = ?
               ORDER BY created_at DESC LIMIT ?""",
            (user_id, limit),
        ).fetchall()
        return [dict(r) for r in reversed(rows)]

    def clear(self, user_id: str) -> None:
        with self._conn:
            self._conn.execute(
                "DELETE FROM conversations WHERE user_id = ?",
                (user_id,),
            )


# ---------------------------------------------------------------------------
# Audit log
# ---------------------------------------------------------------------------


class AuditService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def log(self, user_id: str, action: str, details: str | None = None) -> None:
        """Log an action. Never log sensitive values (tokens, audio, faces)."""
        with self._conn:
            self._conn.execute(
                "INSERT INTO audit_log (user_id, action, details) VALUES (?, ?, ?)",
                (user_id, action[:128], (details or "")[:512]),
            )
        self._prune(user_id)

    def _prune(self, user_id: str) -> None:
        count = self._conn.execute(
            "SELECT COUNT(*) FROM audit_log WHERE user_id = ?",
            (user_id,),
        ).fetchone()[0]
        if count > settings.audit_max_rows:
            excess = count - settings.audit_max_rows
            self._conn.execute(
                """DELETE FROM audit_log WHERE id IN (
                   SELECT id FROM audit_log WHERE user_id = ?
                   ORDER BY created_at ASC LIMIT ?
                )""",
                (user_id, excess),
            )
