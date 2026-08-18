from __future__ import annotations

import json

import httpx
import pytest

from src.ai_assistant.config import Settings
from src.ai_assistant.services.ai_provider import AIProviderError, AIResponse
from src.ai_assistant.services.fallback_provider import FallbackAIProvider
from src.ai_assistant.services.gemini_provider import GeminiProvider


class _FakeProvider:
    def __init__(self, name: str, *, available: bool = True, fail: bool = False):
        self.provider_name = name
        self.model_name = f"{name}-model"
        self.available = available
        self.fail = fail
        self.closed = False

    async def health_check(self) -> bool:
        return self.available

    async def generate(self, prompt, system_prompt, history):
        if self.fail:
            raise AIProviderError("unavailable")
        return AIResponse(
            content=json.dumps({"response_text": f"from {self.provider_name}"}),
            model=self.model_name,
            duration_ms=1,
            provider=self.provider_name,
        )

    async def aclose(self) -> None:
        self.closed = True


@pytest.mark.asyncio
async def test_fallback_uses_ollama_when_gemini_generation_fails():
    gemini = _FakeProvider("gemini", fail=True)
    ollama = _FakeProvider("ollama")
    provider = FallbackAIProvider(gemini, ollama)

    response = await provider.generate("hello")

    assert response.provider == "ollama"
    assert provider.provider_name == "ollama"


@pytest.mark.asyncio
async def test_health_prefers_gemini_when_available():
    provider = FallbackAIProvider(
        _FakeProvider("gemini", available=True),
        _FakeProvider("ollama", available=True),
    )

    assert await provider.health_check() is True
    assert provider.provider_name == "gemini"


@pytest.mark.asyncio
async def test_gemini_interactions_request_is_text_only_and_parses_steps():
    captured_request: httpx.Request | None = None

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal captured_request
        captured_request = request
        return httpx.Response(
            200,
            json={
                "status": "completed",
                "steps": [
                    {
                        "type": "model_output",
                        "content": [
                            {
                                "type": "text",
                                "text": '{"response_text":"Ready."}',
                            }
                        ],
                    }
                ],
            },
        )

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = GeminiProvider(
        api_key="test-key-not-real",
        model="gemini-test",
        client=client,
    )

    response = await provider.generate(
        "reduce sensitivity",
        "system",
        [{"role": "user", "content": "hello"}],
    )

    assert response.provider == "gemini"
    assert response.content == '{"response_text":"Ready."}'
    assert captured_request is not None
    body = json.loads(captured_request.content)
    assert body["store"] is False
    assert isinstance(body["input"], str)
    assert "image" not in body
    assert "audio" not in body
    assert captured_request.headers["x-goog-api-key"] == "test-key-not-real"
    await client.aclose()


def test_google_api_key_takes_precedence_without_exposing_secret():
    configured = Settings(
        _env_file=None,
        gemini_api_key="gemini-key",
        google_api_key="google-key",
    )

    assert configured.selected_gemini_api_key == "google-key"
    assert "google-key" not in repr(configured)


def test_blank_gemini_key_disables_cloud_provider():
    configured = Settings(_env_file=None, gemini_api_key="   ")

    assert configured.selected_gemini_api_key is None
