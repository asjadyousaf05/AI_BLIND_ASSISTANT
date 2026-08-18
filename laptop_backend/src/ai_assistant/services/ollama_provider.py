"""Ollama provider abstraction.

All communication with the Ollama API goes through this module.
Nothing else in the backend calls the Ollama HTTP API directly.
"""

from __future__ import annotations

import json
import logging
import time

import httpx

from ..config import settings
from .ai_provider import AIProviderError, AIResponse

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Structured output from Ollama
# ---------------------------------------------------------------------------


OllamaResponse = AIResponse


# ---------------------------------------------------------------------------
# Ollama implementation
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """You are Vision AI, a friendly, intelligent, and highly capable conversational voice assistant designed for a blind or visually impaired user.

Your responses are spoken aloud via Text-to-Speech (TTS), so follow these principles:
- Natural & Clear: Speak warmly, calmly, and naturally in short, clear sentences. Avoid markdown, asterisks, bullets, code, or long lists.
- Direct Answers: For general questions, explanations, knowledge, advice, conversation, greetings, or descriptions, provide a direct, helpful, and pleasant spoken answer (1-3 sentences).
- Contextual Awareness: Understand conversational context and follow-up questions easily.
- Assistant Actions: If and only if the user asks to perform an explicit app or device action (like creating a reminder, saving a note, listing reminders, checking schedule, or opening a screen), include the appropriate tool_call in your JSON response.

Response Format:
Always respond with valid JSON:
{
  "response_text": "Your helpful spoken voice response."
}

Or when an explicit tool action is requested:
{
  "response_text": "Spoken description of the action.",
  "tool_call": {
    "name": "tool_name",
    "arguments": {}
  }
}

Common Tools:
- get_current_time: Check the current time
- get_current_date: Check the current date
- create_reminder: Create a reminder (args: title, scheduled_at)
- list_reminders: List reminders
- save_note: Save a note (args: title, content)
- list_notes: List notes
- read_note: Read a note (args: note_id)
- create_schedule_entry: Add event to schedule (args: title, starts_at)
- list_schedule: List schedule events
- navigate_to_screen: Open a screen (args: screen e.g. home, settings, ocr_scanner, help)
- trigger_ocr_scan: Scan and read document text
- get_battery_status: Check battery
- provide_daily_summary: Summarize today's reminders and schedule

For all general conversation, questions, and chatting, simply output your helpful answer inside "response_text" without a tool_call."""


class OllamaProvider:
    def __init__(
        self,
        base_url: str = settings.ollama_base_url,
        model: str = settings.ollama_model,
        timeout: float = 120.0,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._model = model
        self._timeout = timeout
        self._client = httpx.AsyncClient(timeout=self._timeout)

    @property
    def provider_name(self) -> str:
        return "ollama"

    @property
    def model_name(self) -> str:
        return self._model

    async def health_check(self) -> bool:
        try:
            r = await self._client.get(f"{self._base_url}/api/tags", timeout=5.0)
            return r.status_code == 200
        except httpx.HTTPError:
            return False

    async def generate(
        self,
        prompt: str,
        system_prompt: str = SYSTEM_PROMPT,
        history: list[dict[str, str]] | None = None,
    ) -> AIResponse:
        messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]
        if history:
            messages.extend(history[-10:])  # Bound history
        messages.append({"role": "user", "content": prompt})

        t0 = time.monotonic()
        try:
            r = await self._client.post(
                f"{self._base_url}/api/chat",
                json={
                    "model": self._model,
                    "messages": messages,
                    "stream": False,
                    "format": "json",
                    "options": {
                        "temperature": 0.3,
                        "num_predict": 512,
                    },
                },
            )
            r.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise OllamaError(f"Ollama HTTP error: {e.response.status_code}") from e
        except httpx.RequestError as e:
            raise OllamaError(f"Ollama connection error: {e}") from e

        duration_ms = int((time.monotonic() - t0) * 1000)
        data = r.json()
        content = data.get("message", {}).get("content", "")
        return AIResponse(
            content=content,
            model=self._model,
            duration_ms=duration_ms,
            provider=self.provider_name,
        )

    async def aclose(self) -> None:
        await self._client.aclose()


class OllamaError(AIProviderError):
    pass


# ---------------------------------------------------------------------------
# Simulated provider for tests (no model required)
# ---------------------------------------------------------------------------


class SimulatedAIProvider:
    """Returns deterministic JSON responses for testing without Ollama."""

    async def health_check(self) -> bool:
        return True

    @property
    def provider_name(self) -> str:
        return "simulated"

    @property
    def model_name(self) -> str:
        return "simulated"

    async def generate(
        self,
        prompt: str,
        system_prompt: str = "",
        history: list[dict[str, str]] | None = None,
    ) -> AIResponse:
        prompt_lower = prompt.lower()

        if "remind" in prompt_lower:
            content = json.dumps(
                {
                    "response_text": "I can create that reminder for you.",
                    "tool_call": {
                        "name": "create_reminder",
                        "arguments": {
                            "title": "Test reminder",
                            "scheduled_at": "2026-08-12T20:00:00+00:00",
                        },
                    },
                    "requires_confirmation": True,
                    "confirmation_prompt": "Create a reminder for tomorrow at 8 PM. Should I continue?",
                }
            )
        elif "note" in prompt_lower:
            content = json.dumps(
                {
                    "response_text": "I can save that note.",
                    "tool_call": {
                        "name": "save_note",
                        "arguments": {
                            "title": "Test note",
                            "content": "This is a test note.",
                        },
                    },
                    "requires_confirmation": False,
                }
            )
        elif "time" in prompt_lower:
            content = json.dumps(
                {
                    "response_text": "Let me get the current time.",
                    "tool_call": {"name": "get_current_time", "arguments": {}},
                    "requires_confirmation": False,
                }
            )
        else:
            content = json.dumps(
                {
                    "response_text": f"I received your message: {prompt[:80]}.",
                }
            )

        return AIResponse(
            content=content,
            model="simulated",
            duration_ms=10,
            provider=self.provider_name,
        )

    async def aclose(self) -> None:
        return None
