"""Authentication service — pairing codes and bearer tokens."""

from __future__ import annotations

import hashlib
import logging
import secrets
import sqlite3
from datetime import UTC, datetime, timedelta

from ..config import settings

logger = logging.getLogger(__name__)

# Never log tokens or pairing codes.


class AuthService:
    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def generate_pairing_code(self, user_id: str, display_name: str) -> str:
        """Generate a short-lived pairing code for a user profile.

        Creates the user record if it does not exist.
        Returns the plaintext code to display in the terminal output.
        The code is NOT stored; only its hash is persisted.
        """
        code = secrets.token_urlsafe(8)[:8].upper()
        code_hash = self._hash(code)
        expires = (datetime.now(UTC) + timedelta(seconds=settings.pairing_code_ttl)).isoformat()

        with self._conn:
            self._conn.execute(
                """
                INSERT INTO users (user_id, display_name, pairing_code, pairing_code_expires_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    display_name = excluded.display_name,
                    pairing_code = excluded.pairing_code,
                    pairing_code_expires_at = excluded.pairing_code_expires_at
                """,
                (user_id, display_name, code_hash, expires),
            )
        return code

    def direct_pair(self, user_id: str = "default_user", display_name: str = "User") -> tuple[str, str, str]:
        """Issue a bearer token directly without requiring a pairing code."""
        token = secrets.token_urlsafe(32)
        token_hash = self._hash(token)
        token_expires = (datetime.now(UTC) + timedelta(days=settings.token_ttl_days)).isoformat()

        with self._conn:
            self._conn.execute(
                """
                INSERT INTO users (user_id, display_name, token_hash, token_expires_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    display_name = excluded.display_name,
                    token_hash = excluded.token_hash,
                    token_expires_at = excluded.token_expires_at,
                    pairing_code = NULL,
                    pairing_code_expires_at = NULL
                """,
                (user_id, display_name, token_hash, token_expires),
            )

        return user_id, token, display_name

    def pair(self, pairing_code: str) -> tuple[str, str, str]:
        """Validate the pairing code and issue a bearer token.

        Returns (user_id, token, display_name) on success.
        Raises AuthError on invalid or expired code.
        """
        code_hash = self._hash(pairing_code)
        now = datetime.now(UTC).isoformat()

        row = self._conn.execute(
            """
            SELECT user_id, display_name, pairing_code_expires_at
            FROM users
            WHERE pairing_code = ? AND pairing_code_expires_at > ?
            """,
            (code_hash, now),
        ).fetchone()

        if row is None:
            raise AuthError("Invalid or expired pairing code.")

        user_id: str = row["user_id"]
        stored_name: str = row["display_name"]

        token = secrets.token_urlsafe(32)
        token_hash = self._hash(token)
        token_expires = (datetime.now(UTC) + timedelta(days=settings.token_ttl_days)).isoformat()

        with self._conn:
            self._conn.execute(
                """
                UPDATE users
                SET token_hash = ?, token_expires_at = ?,
                    pairing_code = NULL, pairing_code_expires_at = NULL
                WHERE user_id = ?
                """,
                (token_hash, token_expires, user_id),
            )

        return user_id, token, stored_name

    def verify_token(self, token: str) -> str | None:
        """Verify a bearer token and return the user_id, or None if invalid."""
        token_hash = self._hash(token)
        now = datetime.now(UTC).isoformat()

        row = self._conn.execute(
            """
            SELECT user_id FROM users
            WHERE token_hash = ? AND token_expires_at > ?
            """,
            (token_hash, now),
        ).fetchone()

        return row["user_id"] if row is not None else None

    def get_user(self, user_id: str) -> dict | None:
        row = self._conn.execute(
            "SELECT user_id, display_name, created_at FROM users WHERE user_id = ?",
            (user_id,),
        ).fetchone()
        return dict(row) if row else None

    @staticmethod
    def _hash(value: str) -> str:
        return hashlib.sha256(value.encode()).hexdigest()


class AuthError(Exception):
    pass
