"""Print a fresh short-lived pairing code for the local phone connection.

Run this interactively only when pairing a new phone or laptop endpoint. The
plaintext code is never stored; only its SHA-256 digest enters local SQLite.
"""

from __future__ import annotations

from ai_assistant.config import settings
from ai_assistant.db.database import get_connection, migrate
from ai_assistant.services.auth import AuthService


def main() -> None:
    connection = get_connection(settings.db_path)
    try:
        migrate(connection)
        code = AuthService(connection).generate_pairing_code("default_user", "User")
        print("Enter this one-time code in the app within five minutes:")
        print(code)
    finally:
        connection.close()


if __name__ == "__main__":
    main()
