"""Whisper-based local speech-to-text transcription.

Uses faster-whisper for CPU-efficient local transcription. Production requests
fail truthfully when the package or prepared model is unavailable; the separate
simulated provider is injected only by tests.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Protocol

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Transcription interface
# ---------------------------------------------------------------------------


class TranscriptionProvider(Protocol):
    def transcribe(self, audio_path: str | Path, language: str | None = None) -> str: ...

    def is_available(self) -> bool: ...


# ---------------------------------------------------------------------------
# faster-whisper implementation
# ---------------------------------------------------------------------------


class WhisperTranscriptionProvider:
    """Transcribes audio using faster-whisper (CPU, no GPU required)."""

    def __init__(
        self,
        model_size: str = "medium",
        language: str = "en",
        *,
        local_files_only: bool = True,
    ) -> None:
        self._model_size = model_size
        self._language = language
        self._local_files_only = local_files_only
        self._model = None
        self._available = False
        self._load()

    def _load(self) -> None:
        try:
            from faster_whisper import WhisperModel  # type: ignore

            logger.info("Loading Whisper model: %s", self._model_size)
            self._model = WhisperModel(
                self._model_size,
                device="cpu",
                compute_type="int8",
                local_files_only=self._local_files_only,
            )
            self._available = True
            logger.info("Whisper model loaded successfully")
        except ImportError:
            logger.warning(
                "faster-whisper is not installed. Voice transcription is unavailable. "
                "Install the backend dependencies and prepare the selected model."
            )
            self._available = False
        except Exception as error:  # noqa: BLE001 - optional native model boundary
            logger.error("Failed to load Whisper model: %s", type(error).__name__)
            self._available = False

    def is_available(self) -> bool:
        return self._available

    def transcribe(self, audio_path: str | Path, language: str | None = None) -> str:
        if not self._available or self._model is None:
            raise TranscriptionError(
                "Whisper model is not available. "
                "Install faster-whisper and ensure the model is downloaded."
            )

        audio_path = Path(audio_path)
        if not audio_path.exists():
            raise TranscriptionError("The audio recording is unavailable. Please record it again.")

        size_bytes = audio_path.stat().st_size
        if size_bytes < 256:
            raise TranscriptionError("Audio file is too small — likely silence.")
        if size_bytes > 4 * 1024 * 1024:
            raise TranscriptionError("Audio file exceeds maximum size (4 MB).")

        try:
            selected_language = language if language is not None else self._language
            segments, _info = self._model.transcribe(
                str(audio_path),
                language=None if selected_language == "auto" else selected_language,
                beam_size=5,
                temperature=0.0,
                condition_on_previous_text=False,
                word_timestamps=False,
                vad_filter=True,
            )
            parts = []
            for segment in segments:
                part = segment.text.strip()
                if not part:
                    continue
                # Reject the whole utterance rather than silently dropping an
                # unclear segment that could contain a negation or tool argument.
                if segment.avg_logprob < -1.0 or segment.compression_ratio > 2.4:
                    raise TranscriptionError(
                        "Speech was unclear. Please repeat your full question or type it."
                    )
                parts.append(part)
            text = " ".join(parts)
            if not text:
                raise TranscriptionError("No speech detected in the audio.")
            return text
        except TranscriptionError:
            raise
        except Exception as error:
            # Decoder exceptions can contain local paths or audio details.
            raise TranscriptionError(
                "Speech could not be recognized. Please record your question again."
            ) from error


# ---------------------------------------------------------------------------
# Simulated provider for tests
# ---------------------------------------------------------------------------


class SimulatedTranscriptionProvider:
    """Returns a fixed transcript for testing without Whisper."""

    def is_available(self) -> bool:
        return True

    def transcribe(self, audio_path: str | Path, language: str | None = None) -> str:
        logger.debug("SimulatedTranscriptionProvider: returning fixed transcript")
        return "Please set a reminder for tomorrow at eight PM"


# ---------------------------------------------------------------------------
# Exception
# ---------------------------------------------------------------------------


class TranscriptionError(Exception):
    pass
