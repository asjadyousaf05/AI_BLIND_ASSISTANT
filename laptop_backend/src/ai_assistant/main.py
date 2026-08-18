"""FastAPI application entry point with startup pairing code generation."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI

from .config import settings
from .db.database import get_connection, migrate
from .routers import assistant, auth, health
from .services.auth import AuthService
from .services.fallback_provider import FallbackAIProvider
from .services.gemini_provider import GeminiProvider
from .services.ollama_provider import OllamaProvider, SimulatedAIProvider
from .services.transcription import (
    SimulatedTranscriptionProvider,
    WhisperTranscriptionProvider,
)
from .services.user_data import AuditService

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# App factory
# ---------------------------------------------------------------------------


def create_app(
    use_simulated_ai: bool = False,
    use_simulated_transcription: bool = False,
) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        # ── Startup ──────────────────────────────────────────────────────
        logging.basicConfig(
            level=settings.log_level.upper(),
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        )

        # Database
        conn = get_connection(settings.db_path)
        migrate(conn)
        app.state.db = conn
        app.state.settings = settings

        # AI provider
        if use_simulated_ai:
            app.state.ai_provider = SimulatedAIProvider()
            logger.info("Using simulated AI provider (tests)")
        else:
            ollama_provider = OllamaProvider(
                base_url=settings.ollama_base_url,
                model=settings.ollama_model,
            )
            gemini_api_key = settings.selected_gemini_api_key
            if gemini_api_key:
                gemini_provider = GeminiProvider(
                    api_key=gemini_api_key,
                    model=settings.gemini_model,
                    base_url=settings.gemini_base_url,
                )
                app.state.ai_provider = FallbackAIProvider(
                    primary=gemini_provider,
                    fallback=ollama_provider,
                )
                logger.info(
                    "Gemini primary configured (%s); Ollama local fallback configured (%s).",
                    settings.gemini_model,
                    settings.ollama_model,
                )
            else:
                app.state.ai_provider = ollama_provider
                logger.info(
                    "No Gemini API key configured; using local Ollama model %s.",
                    settings.ollama_model,
                )

        # Transcription provider
        if use_simulated_transcription:
            app.state.transcription_provider = SimulatedTranscriptionProvider()
            logger.info("Using simulated transcription (tests)")
        else:
            app.state.transcription_provider = WhisperTranscriptionProvider(
                model_size=settings.whisper_model,
                language=settings.whisper_language,
                local_files_only=settings.whisper_local_files_only,
            )

        # Auth service
        auth_service = AuthService(conn)
        app.state.auth_service = auth_service
        app.state.audit_service = AuditService(conn)

        # Generate and display the default user pairing code
        user_id = "default_user"
        display_name = "User"
        code = auth_service.generate_pairing_code(user_id, display_name)

        logger.info("=" * 60)
        logger.info("AI Blind Assistant backend started.")
        logger.info(
            "Preferred AI provider: %s (%s)",
            app.state.ai_provider.provider_name,
            app.state.ai_provider.model_name,
        )
        logger.info("Protocol: v%d", settings.protocol_version)
        # The one-time secret is shown interactively but never written through
        # the logging subsystem, where it could be retained by a file handler.
        print("\n  ╔══════════════════════════════╗", flush=True)
        print(f"  ║  PAIRING CODE: {code:<13} ║", flush=True)
        print("  ╚══════════════════════════════╝\n", flush=True)
        logger.info("A one-time pairing code was displayed in this terminal.")
        logger.info("Enter the displayed code in the Flutter app to pair.")
        logger.info("Code expires in %d seconds.", settings.pairing_code_ttl)
        logger.info("=" * 60)

        yield

        # ── Shutdown ─────────────────────────────────────────────────────
        conn.close()
        if not use_simulated_ai and hasattr(app.state, "ai_provider"):
            await app.state.ai_provider.aclose()
        logger.info("Backend shut down.")

    app = FastAPI(
        title="AI Blind Assistant Backend",
        description=(
            "Paired assistant backend for the AI Blind Assistant app. Common app controls "
            "are deterministic; conversation uses Gemini when configured and otherwise Ollama."
        ),
        version="1.1.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url=None,
    )

    # Routers
    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(assistant.router)

    return app


app = create_app()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    uvicorn.run(
        "src.ai_assistant.main:app",
        host=settings.host,
        port=settings.port,
        reload=False,
        log_level=settings.log_level.lower(),
    )
