"""Unit tests for the auth service."""

from __future__ import annotations

import sqlite3

import pytest

from src.ai_assistant.db.database import migrate
from src.ai_assistant.services.auth import AuthError, AuthService


@pytest.fixture
def db():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    migrate(conn)
    return conn


@pytest.fixture
def auth(db):
    return AuthService(db)


class TestAuthService:
    def test_generate_and_pair_success(self, auth):
        code = auth.generate_pairing_code("user_1", "Alice")
        assert len(code) > 0

        user_id, token, name = auth.pair(code)
        assert user_id == "user_1"
        assert name == "Alice"
        assert len(token) > 10

    def test_wrong_code_raises_error(self, auth):
        auth.generate_pairing_code("user_2", "Bob")
        with pytest.raises(AuthError):
            auth.pair("WRONGCODE")

    def test_token_verification(self, auth):
        code = auth.generate_pairing_code("user_3", "Carol")
        _, token, _ = auth.pair(code)

        verified_uid = auth.verify_token(token)
        assert verified_uid == "user_3"

    def test_invalid_token_returns_none(self, auth):
        result = auth.verify_token("notavalidtoken")
        assert result is None

    def test_pairing_code_consumed_after_use(self, auth):
        """Code should not be reusable."""
        code = auth.generate_pairing_code("user_4", "Dave")
        auth.pair(code)
        # Code is cleared after first use
        with pytest.raises(AuthError):
            auth.pair(code)

    def test_get_user_returns_profile(self, auth):
        code = auth.generate_pairing_code("user_5", "Eve")
        auth.pair(code)
        user = auth.get_user("user_5")
        assert user is not None
        assert user["display_name"] == "Eve"

    def test_regenerate_code_replaces_old(self, auth):
        old_code = auth.generate_pairing_code("user_6", "Frank")
        new_code = auth.generate_pairing_code("user_6", "Frank")
        # Old code should now be invalid (replaced)
        with pytest.raises(AuthError):
            auth.pair(old_code)
        # New code works
        user_id, _, _ = auth.pair(new_code)
        assert user_id == "user_6"
