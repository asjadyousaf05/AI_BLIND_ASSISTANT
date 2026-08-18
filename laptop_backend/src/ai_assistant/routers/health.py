"""Health check router."""

from __future__ import annotations

from fastapi import APIRouter, Request

from ..models.schemas import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
async def health(req: Request) -> HealthResponse:
    """Return provider/fallback availability and protocol version.

    No authentication required so the phone can ping before pairing.
    """
    ai_provider = req.app.state.ai_provider
    ai_ok = await ai_provider.health_check()
    fallback_name = getattr(ai_provider, "fallback_provider_name", None)
    preferred_name = getattr(
        ai_provider,
        "primary_provider_name",
        ai_provider.provider_name,
    )
    if fallback_name == "ollama":
        ollama_ok = await ai_provider.fallback_health_check()
    else:
        ollama_ok = ai_ok if ai_provider.provider_name == "ollama" else False

    return HealthResponse(
        status="ok",
        protocol_version=req.app.state.settings.protocol_version,
        model=ai_provider.model_name,
        provider=ai_provider.provider_name,
        preferred_provider=preferred_name,
        fallback_provider=fallback_name,
        ai_available=ai_ok,
        gemini_configured=req.app.state.settings.selected_gemini_api_key is not None,
        ollama_available=ollama_ok,
    )
