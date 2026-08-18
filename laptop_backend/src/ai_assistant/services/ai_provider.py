"""Provider-neutral contracts for conversational AI generation."""

from __future__ import annotations

from typing import Protocol


class AIResponse:
    def __init__(
        self,
        content: str,
        model: str,
        duration_ms: int,
        provider: str,
    ) -> None:
        self.content = content
        self.model = model
        self.duration_ms = duration_ms
        self.provider = provider


class AIProvider(Protocol):
    @property
    def provider_name(self) -> str: ...

    @property
    def model_name(self) -> str: ...

    async def generate(
        self,
        prompt: str,
        system_prompt: str,
        history: list[dict[str, str]],
    ) -> AIResponse: ...

    async def health_check(self) -> bool: ...

    async def aclose(self) -> None: ...


class AIProviderError(Exception):
    """A provider failed without exposing credentials or user content."""
