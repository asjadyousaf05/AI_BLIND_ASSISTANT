"""Text-only Gemini provider using Google's current Interactions REST API.

The provider receives transcripts and typed conversation text only. Camera
frames and raw audio are never accepted by this class. API keys are supplied in
the request header and are never logged or returned to the phone.
"""

from __future__ import annotations

import time

import httpx

from .ai_provider import AIProviderError, AIResponse


class GeminiProvider:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        base_url: str = "https://generativelanguage.googleapis.com/v1beta",
        timeout: float = 60.0,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        if not api_key.strip():
            raise ValueError("A Gemini API key is required.")
        self._api_key = api_key
        self._model = model
        self._base_url = base_url.rstrip("/")
        self._client = client or httpx.AsyncClient(timeout=timeout)
        self._owns_client = client is None

    @property
    def provider_name(self) -> str:
        return "gemini"

    @property
    def model_name(self) -> str:
        return self._model

    async def health_check(self) -> bool:
        try:
            response = await self._client.get(
                f"{self._base_url}/models/{self._model}",
                headers=self._headers,
                timeout=5.0,
            )
            return response.status_code == 200
        except httpx.HTTPError:
            return False

    async def generate(
        self,
        prompt: str,
        system_prompt: str,
        history: list[dict[str, str]] | None = None,
    ) -> AIResponse:
        bounded_history = history[-10:] if history else []
        context = "\n".join(
            f"{item.get('role', 'user')}: {item.get('content', '')[:4096]}"
            for item in bounded_history
        )
        model_input = (
            f"Recent conversation:\n{context}\n\nCurrent user request:\n{prompt}"
            if context
            else prompt
        )
        payload = {
            "model": self._model,
            "store": False,
            "system_instruction": system_prompt,
            "input": model_input,
            "generation_config": {"temperature": 0.3, "max_output_tokens": 512},
            "response_format": {
                "type": "text",
                "mime_type": "application/json",
                "schema": _ASSISTANT_RESPONSE_SCHEMA,
            },
        }

        started = time.monotonic()
        try:
            response = await self._client.post(
                f"{self._base_url}/interactions",
                headers=self._headers,
                json=payload,
            )
            response.raise_for_status()
            content = _extract_output_text(response.json())
        except httpx.HTTPStatusError as exc:
            raise GeminiError(f"Gemini HTTP error: {exc.response.status_code}") from exc
        except (httpx.RequestError, TypeError, ValueError, KeyError) as exc:
            raise GeminiError("Gemini is unavailable or returned an invalid response.") from exc

        if not content.strip():
            raise GeminiError("Gemini returned an empty response.")
        return AIResponse(
            content=content,
            model=self._model,
            duration_ms=int((time.monotonic() - started) * 1000),
            provider=self.provider_name,
        )

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    @property
    def _headers(self) -> dict[str, str]:
        return {
            "x-goog-api-key": self._api_key,
            "Content-Type": "application/json",
        }


class GeminiError(AIProviderError):
    pass


def _extract_output_text(data: dict) -> str:
    text_blocks: list[str] = []
    for step in reversed(data.get("steps", [])):
        if step.get("type") != "model_output":
            continue
        for content in step.get("content", []):
            if content.get("type") == "text" and isinstance(content.get("text"), str):
                text_blocks.append(content["text"])
        if text_blocks:
            break
    return "".join(text_blocks)


_ASSISTANT_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "response_text": {"type": "string"},
        "tool_call": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "arguments": {"type": "object", "additionalProperties": True},
            },
            "required": ["name", "arguments"],
        },
        "requires_confirmation": {"type": "boolean"},
        "confirmation_prompt": {"type": "string"},
    },
    "required": ["response_text"],
}
