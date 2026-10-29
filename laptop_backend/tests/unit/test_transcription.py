"""Recognition regressions without downloading models or using personal audio."""

from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from src.ai_assistant.services.transcription import (
    TranscriptionError,
    WhisperTranscriptionProvider,
)


def segment(text, *, logprob=-0.2, compression=1.1):
    return SimpleNamespace(text=text, avg_logprob=logprob, compression_ratio=compression)


@pytest.fixture
def transcriber(tmp_path, monkeypatch):
    monkeypatch.setattr(WhisperTranscriptionProvider, "_load", lambda self: None)
    provider = WhisperTranscriptionProvider(language="ur")
    provider._available = True
    provider._model = Mock()
    provider._model.transcribe.return_value = (iter([segment(" A clear question. ")]), None)
    audio = tmp_path / "synthetic.wav"
    audio.write_bytes(b"\0" * 512)
    return provider, audio


@pytest.mark.parametrize(("override", "expected"), [(None, "ur"), ("en", "en"), ("auto", None)])
def test_uses_configured_language_unless_explicitly_overridden(transcriber, override, expected):
    provider, audio = transcriber
    assert provider.transcribe(audio, language=override) == "A clear question."
    assert provider._model.transcribe.call_args.kwargs["language"] == expected


def test_configured_auto_language_reaches_decoder_as_detection(transcriber):
    provider, audio = transcriber
    provider._language = "auto"
    provider.transcribe(audio)
    assert provider._model.transcribe.call_args.kwargs["language"] is None


def test_question_decoding_is_deterministic_and_has_no_invented_prompt(transcriber):
    provider, audio = transcriber
    provider.transcribe(audio)
    options = provider._model.transcribe.call_args.kwargs
    assert options["temperature"] == 0.0
    assert options["condition_on_previous_text"] is False
    assert options["vad_filter"] is True
    assert not options.get("initial_prompt")


def test_proper_names_are_preserved_without_command_autocorrection(transcriber):
    provider, audio = transcriber
    question = "What do you know about Quaid-i-Azam University?"
    provider._model.transcribe.return_value = (iter([segment(question)]), None)
    assert provider.transcribe(audio) == question


@pytest.mark.parametrize(
    "unclear", [segment("do not", logprob=-1.1), segment("no no no", compression=2.5)]
)
def test_unclear_segment_rejects_entire_utterance_including_clear_command(transcriber, unclear):
    provider, audio = transcriber
    provider._model.transcribe.return_value = (
        iter([segment("Start mobile mode."), unclear]),
        None,
    )
    with pytest.raises(TranscriptionError, match="repeat your full question"):
        provider.transcribe(audio)


@pytest.mark.parametrize("segments", [[], [segment(" ")]])
def test_silence_is_not_submitted_as_a_question(transcriber, segments):
    provider, audio = transcriber
    provider._model.transcribe.return_value = (iter(segments), None)
    with pytest.raises(TranscriptionError, match="No speech detected"):
        provider.transcribe(audio)


def test_lazy_decoder_failure_does_not_expose_audio_or_local_paths(transcriber, caplog):
    provider, audio = transcriber
    private_detail = "private-audio-content-and-path"

    def broken_segments():
        yield segment("Partial output")
        raise RuntimeError(private_detail)

    provider._model.transcribe.return_value = (broken_segments(), None)
    with pytest.raises(TranscriptionError, match="record your question again") as caught:
        provider.transcribe(audio)
    assert private_detail not in str(caught.value)
    assert private_detail not in caplog.text


def test_unavailable_model_fails_without_attempting_decode(transcriber):
    provider, audio = transcriber
    provider._available = False
    with pytest.raises(TranscriptionError, match="not available"):
        provider.transcribe(audio)
    provider._model.transcribe.assert_not_called()


@pytest.mark.parametrize("size", [0, 255, 4 * 1024 * 1024 + 1])
def test_empty_and_oversize_audio_never_reach_decoder(transcriber, size):
    provider, audio = transcriber
    with audio.open("wb") as handle:
        handle.truncate(size)
    with pytest.raises(TranscriptionError):
        provider.transcribe(audio)
    provider._model.transcribe.assert_not_called()


def test_missing_audio_error_does_not_reveal_path(transcriber):
    provider, audio = transcriber
    audio.unlink()
    with pytest.raises(TranscriptionError) as caught:
        provider.transcribe(audio)
    assert str(audio) not in str(caught.value)


def test_unclear_audio_http_request_never_reaches_query_routing(transcriber, tmp_path, monkeypatch):
    from fastapi.testclient import TestClient

    from src.ai_assistant.config import settings
    from src.ai_assistant.main import create_app
    from src.ai_assistant.routers import assistant

    provider, _ = transcriber
    provider._model.transcribe.return_value = (iter([segment("start", logprob=-1.5)]), None)
    monkeypatch.setattr(settings, "db_path", tmp_path / "speech-test.db")
    monkeypatch.setattr(assistant, "_audio_duration_seconds", lambda path: 1.0)
    route_query = Mock(side_effect=AssertionError("Unclear speech reached command routing"))
    monkeypatch.setattr(assistant, "text_query", route_query)
    app = create_app(use_simulated_ai=True, use_simulated_transcription=True)
    with TestClient(app) as client:
        app.state.transcription_provider = provider
        code = app.state.auth_service.generate_pairing_code("speech-test", "Test")
        _, token, _ = app.state.auth_service.pair(code)
        response = client.post(
            "/assistant/audio",
            headers={"Authorization": f"Bearer {token}"},
            files={"audio": ("synthetic.wav", b"\0" * 512, "audio/wav")},
        )
    assert response.status_code == 422
    assert "repeat your full question" in response.json()["detail"]
    route_query.assert_not_called()


@pytest.mark.parametrize("outcome", ["success", "unclear", "too_long"])
def test_http_audio_clip_is_deleted_after_processing(transcriber, tmp_path, monkeypatch, outcome):
    from pathlib import Path

    from fastapi.testclient import TestClient

    from src.ai_assistant.config import settings
    from src.ai_assistant.main import create_app
    from src.ai_assistant.routers import assistant

    provider, _ = transcriber
    original_tempfile = assistant.tempfile.NamedTemporaryFile
    paths = []

    def temporary_clip(**kwargs):
        clip = original_tempfile(dir=tmp_path, **kwargs)
        paths.append(Path(clip.name))
        return clip

    def decode(path, **kwargs):
        assert Path(path).exists()
        return iter(
            [segment("What does offline mean?", logprob=-1.5 if outcome == "unclear" else -0.2)]
        ), None

    provider._model.transcribe.side_effect = decode
    monkeypatch.setattr(settings, "db_path", tmp_path / "audio-cleanup.db")
    monkeypatch.setattr(assistant.tempfile, "NamedTemporaryFile", temporary_clip)
    monkeypatch.setattr(
        assistant, "_audio_duration_seconds", lambda path: 31.0 if outcome == "too_long" else 1.0
    )
    app = create_app(use_simulated_ai=True, use_simulated_transcription=True)
    with TestClient(app) as client:
        app.state.transcription_provider = provider
        code = app.state.auth_service.generate_pairing_code("cleanup-test", "Test")
        _, token, _ = app.state.auth_service.pair(code)
        response = client.post(
            "/assistant/audio",
            headers={"Authorization": f"Bearer {token}"},
            files={"audio": ("synthetic.wav", b"\0" * 512, "audio/wav")},
        )
    assert response.status_code == {"success": 200, "unclear": 422, "too_long": 413}[outcome]
    assert len(paths) == 1
    assert not paths[0].exists()
