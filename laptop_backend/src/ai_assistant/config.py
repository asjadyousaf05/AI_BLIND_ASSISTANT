"""
AI Blind Assistant — Laptop Backend
====================================
FastAPI server that bridges the Flutter Android app with a locally running
Ollama language model.

Environment variables (see .env.example):
  GEMINI_API_KEY    - Optional Gemini primary provider key
  GOOGLE_API_KEY    - Optional Gemini key; takes precedence when both exist
  GEMINI_MODEL      - Gemini model (default: gemini-3.6-flash)
  OLLAMA_BASE_URL   - Ollama API URL (default: http://localhost:11434)
  OLLAMA_MODEL      - Model name (default: llama3.2:3b)
  WHISPER_MODEL     - Whisper model size (default: base)
  DB_PATH           - SQLite database path (default: ./data/assistant.db)
  PAIRING_CODE_TTL  - Seconds a pairing code is valid (default: 300)
  TOKEN_TTL_DAYS    - Bearer token lifetime in days (default: 30)
  AUDIT_MAX_ROWS    - Maximum audit log rows per user (default: 500)
  LOG_LEVEL         - Logging level (default: INFO)
  HOST              - Bind host (default: 0.0.0.0)
  PORT              - Bind port (default: 8765)

Security note:
  This server is intended for use only on a trusted local Wi-Fi network.
  HTTP traffic is not encrypted. Never expose this server to the public
  internet or port-forward it. The application layer provides pairing
  authentication and token authorization.
"""

from __future__ import annotations

from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Optional cloud reasoning. GOOGLE_API_KEY takes precedence when both are set.
    gemini_api_key: SecretStr | None = None
    google_api_key: SecretStr | None = None
    gemini_model: str = "gemini-3.6-flash"
    gemini_base_url: str = "https://generativelanguage.googleapis.com/v1beta"

    # Ollama
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2:3b"

    # Whisper transcription
    whisper_model: str = "base"
    whisper_language: str = "en"
    whisper_local_files_only: bool = True

    # Database
    db_path: Path = Path("./data/assistant.db")

    # Auth
    pairing_code_ttl: int = 300  # seconds
    token_ttl_days: int = 30

    # Audit
    audit_max_rows: int = 500
    persist_conversation_history: bool = False

    # Server
    host: str = "0.0.0.0"
    port: int = 8765
    log_level: str = "INFO"

    # Protocol
    protocol_version: int = 1

    # Audio limits
    max_audio_size_bytes: int = 4 * 1024 * 1024  # 4 MB
    max_audio_duration_seconds: int = 30

    @property
    def selected_gemini_api_key(self) -> str | None:
        selected = self.google_api_key or self.gemini_api_key
        if selected is None:
            return None
        value = selected.get_secret_value().strip()
        return value or None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
