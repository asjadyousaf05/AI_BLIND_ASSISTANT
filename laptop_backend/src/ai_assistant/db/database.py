"""SQLite database initialization and migration."""

from __future__ import annotations

import logging
import sqlite3
from pathlib import Path

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Schema migrations (append-only)
# ---------------------------------------------------------------------------

_MIGRATIONS: list[str] = [
    # 001 — initial schema
    """
    CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS users (
        user_id     TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        pairing_code TEXT,
        pairing_code_expires_at TEXT,
        token_hash  TEXT,
        token_expires_at TEXT
    );

    CREATE TABLE IF NOT EXISTS reminders (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(user_id),
        title       TEXT NOT NULL,
        note        TEXT,
        scheduled_at TEXT NOT NULL,
        timezone    TEXT NOT NULL DEFAULT 'UTC',
        completed   INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS notes (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(user_id),
        title       TEXT NOT NULL,
        content     TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS schedule_entries (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(user_id),
        title       TEXT NOT NULL,
        starts_at   TEXT NOT NULL,
        ends_at     TEXT,
        timezone    TEXT NOT NULL DEFAULT 'UTC',
        description TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS preferences (
        user_id     TEXT NOT NULL REFERENCES users(user_id),
        key         TEXT NOT NULL,
        value       TEXT NOT NULL,
        updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, key)
    );

    CREATE TABLE IF NOT EXISTS memories (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(user_id),
        content     TEXT NOT NULL,
        source      TEXT NOT NULL DEFAULT 'explicit',
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS conversations (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(user_id),
        role        TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
        content     TEXT NOT NULL,
        tool_name   TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS audit_log (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT NOT NULL,
        action      TEXT NOT NULL,
        details     TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id);
    CREATE INDEX IF NOT EXISTS idx_notes_user ON notes(user_id);
    CREATE INDEX IF NOT EXISTS idx_schedule_user ON schedule_entries(user_id);
    CREATE INDEX IF NOT EXISTS idx_memories_user ON memories(user_id);
    CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id, created_at);
    """,
]


def get_connection(db_path: Path) -> sqlite3.Connection:
    """Return a thread-safe SQLite connection with WAL mode and FK enforcement."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def migrate(conn: sqlite3.Connection) -> None:
    """Apply all pending migrations in order."""
    with conn:
        # Ensure schema_version table exists first
        conn.execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        applied = {row[0] for row in conn.execute("SELECT version FROM schema_version")}

    for i, migration_sql in enumerate(_MIGRATIONS, start=1):
        if i not in applied:
            logger.info("Applying migration %d", i)
            with conn:
                conn.executescript(migration_sql)
                conn.execute(
                    "INSERT OR IGNORE INTO schema_version (version) VALUES (?)",
                    (i,),
                )
            logger.info("Migration %d applied", i)
