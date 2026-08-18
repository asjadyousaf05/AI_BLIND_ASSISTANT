"""Gemini-primary provider with automatic local Ollama fallback."""

from __future__ import annotations

import logging

from .ai_provider import AIProvider, AIProviderError, AIResponse
from .ollama_provider import SYSTEM_PROMPT

logger = logging.getLogger(__name__)


class FallbackAIProvider:
    def __init__(self, primary: AIProvider, fallback: AIProvider) -> None:
        self._primary = primary
        self._fallback = fallback
        self._active = primary

    @property
    def provider_name(self) -> str:
        return self._active.provider_name

    @property
    def model_name(self) -> str:
        return self._active.model_name

    @property
    def primary_provider_name(self) -> str:
        return self._primary.provider_name

    @property
    def fallback_provider_name(self) -> str:
        return self._fallback.provider_name

    async def health_check(self) -> bool:
        if await self._primary.health_check():
            self._active = self._primary
            return True
        self._active = self._fallback
        return await self._fallback.health_check()

    async def fallback_health_check(self) -> bool:
        return await self._fallback.health_check()

    async def generate(
        self,
        prompt: str,
        system_prompt: str = SYSTEM_PROMPT,
        history: list[dict[str, str]] | None = None,
    ) -> AIResponse:
        try:
            response = await self._primary.generate(prompt, system_prompt, history or [])
            self._active = self._primary
            return response
        except AIProviderError:
            logger.warning("Primary AI provider unavailable; using the configured local fallback.")
            self._active = self._fallback
            return await self._fallback.generate(prompt, system_prompt, history or [])

    async def aclose(self) -> None:
        await self._primary.aclose()
        await self._fallback.aclose()
