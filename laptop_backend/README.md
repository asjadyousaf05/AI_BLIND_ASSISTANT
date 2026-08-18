# AI Blind Assistant Laptop Backend

This paired FastAPI service provides local speech transcription, deterministic
app-control routing, and conversational AI for the Flutter application.

- Common controls are matched locally and validated against a strict tool list.
- Voice is transcribed locally with faster-whisper base.
- Gemini is preferred only when `GOOGLE_API_KEY` or `GEMINI_API_KEY` exists.
- Any Gemini failure automatically falls back to local Ollama `llama3.2:3b`.
- Camera frames and raw recordings are never sent to Gemini.
- Conversation persistence is disabled by default.

See [the assistant architecture and setup](../docs/assistant.md) for privacy,
commands, installation, pairing, provider configuration, and verification.

Quick validation:

```bash
uv pip install --python .venv/bin/python -e '.[dev]'
.venv/bin/ruff check src tests
.venv/bin/pytest -q
```

Run:

```bash
.venv/bin/python -m uvicorn src.ai_assistant.main:app --host 0.0.0.0 --port 8765
```

Use only on a trusted private LAN. Never expose port 8765 publicly or commit a
real `.env` file.
