"""Security and malformed-input regressions from the whole-project audit."""

import json

import pytest
from fastapi.testclient import TestClient

from src.ai_assistant.config import settings
from src.ai_assistant.main import create_app
from src.ai_assistant.services.ollama_provider import AIResponse
from src.ai_assistant.services.user_data import NoteService

from .test_api import _silent_wav


@pytest.fixture
def session(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "db_path", tmp_path / "audit.db")
    app = create_app(use_simulated_ai=True, use_simulated_transcription=True)
    with TestClient(app) as client:
        code = app.state.auth_service.generate_pairing_code("audit-user", "Test")
        _, token, _ = app.state.auth_service.pair(code)
        yield client, app, {"Authorization": f"Bearer {token}"}


@pytest.mark.parametrize("code", ["", " ", "WRONG", "DIRECT", "AUTO", "NONE"])
def test_pairing_rejects_invalid_codes_without_issuing_tokens(session, code):
    client, _, _ = session
    assert client.post("/auth/pair", json={"pairing_code": code}).status_code in {401, 422}


def test_direct_pairing_cannot_replace_an_existing_token(session):
    client, _, headers = session
    assert client.post("/auth/pair/direct").status_code in {403, 404, 405}
    assert client.get("/assistant/notes", headers=headers).status_code == 200


@pytest.mark.parametrize(
    "history",
    [
        "{}",
        '"text"',
        "null",
        '[{"role":"bad","content":"x"}]',
        '[{"role":"user","content":4}]',
        "[]" * 2,
    ],
)
def test_audio_history_validation_returns_client_error(session, history):
    client, _, headers = session
    response = client.post(
        "/assistant/audio",
        headers=headers,
        files={"audio": ("voice.wav", _silent_wav(0.1), "audio/wav")},
        data={"history": history},
    )
    assert response.status_code == 422


def test_unreadable_audio_does_not_reach_transcription(session):
    client, _, headers = session
    response = client.post(
        "/assistant/audio",
        headers=headers,
        files={"audio": ("voice.wav", b"invalid audio" * 100, "audio/wav")},
    )
    assert response.status_code == 422


def test_audio_duration_limit_is_enforced(session):
    client, _, headers = session
    response = client.post(
        "/assistant/audio",
        headers=headers,
        files={"audio": ("voice.wav", _silent_wav(31), "audio/wav")},
    )
    assert response.status_code == 413


@pytest.mark.parametrize("confirm", [True, False])
def test_server_deletion_requires_bound_single_use_confirmation(session, confirm):
    client, app, headers = session
    notes = NoteService(app.state.db)
    note_id = notes.save("audit-user", "Keep until confirmed", "Synthetic test data")

    class Provider:
        async def generate(self, **kwargs):
            return AIResponse(
                content=json.dumps(
                    {
                        "response_text": "Delete this note?",
                        "tool_call": {
                            "name": "delete_note",
                            "arguments": {"note_id": note_id},
                        },
                    }
                ),
                provider="simulated",
                model="test",
                duration_ms=0,
            )

    app.state.ai_provider = Provider()
    response = client.post(
        "/assistant/query", headers=headers, json={"query": "remove my saved item"}
    )
    assert response.status_code == 200
    proposal = response.json()
    assert notes.read("audit-user", note_id) is not None
    assert proposal["requires_confirmation"] is True
    assert proposal["tool_call"]["name"] == "delete_note"
    result = {
        "request_id": proposal["request_id"],
        "tool_result": {"tool_name": "delete_note", "success": confirm},
    }
    completed = client.post("/assistant/tool-result", headers=headers, json=result)
    assert completed.status_code == 200
    assert (notes.read("audit-user", note_id) is None) == confirm
    assert client.post("/assistant/tool-result", headers=headers, json=result).status_code == 409


@pytest.mark.parametrize(
    "tool_call",
    [{"name": [], "arguments": {}}, {"name": "change_feedback_mode", "arguments": {"mode": []}}],
)
def test_malformed_model_tools_do_not_crash_api(session, tool_call):
    client, app, headers = session

    class Provider:
        async def generate(self, **kwargs):
            return AIResponse(
                content=json.dumps({"tool_call": tool_call}),
                provider="simulated",
                model="test",
                duration_ms=0,
            )

    app.state.ai_provider = Provider()
    response = client.post("/assistant/query", headers=headers, json={"query": "hello assistant"})
    assert response.status_code == 200
    assert response.json()["tool_call"] is None


def _model_proposal(app, name, arguments, requires_confirmation=False):
    class Provider:
        async def generate(self, **kwargs):
            return AIResponse(
                content=json.dumps(
                    {
                        "response_text": "Proposed action",
                        "tool_call": {
                            "name": name,
                            "arguments": arguments,
                        },
                        "requires_confirmation": requires_confirmation,
                    }
                ),
                provider="simulated",
                model="test",
                duration_ms=0,
            )

    app.state.ai_provider = Provider()


def test_confirmation_is_bound_to_user_request_and_tool(session):
    client, app, headers = session
    notes = NoteService(app.state.db)
    note_id = notes.save("audit-user", "Preserve", "Synthetic data")
    _model_proposal(app, "delete_note", {"note_id": note_id})
    proposal = client.post(
        "/assistant/query", headers=headers, json={"query": "remove saved item"}
    ).json()
    code = app.state.auth_service.generate_pairing_code("other-user", "Test")
    _, other_token, _ = app.state.auth_service.pair(code)
    result = {
        "request_id": proposal["request_id"],
        "tool_result": {"tool_name": "delete_note", "success": True},
    }
    assert (
        client.post(
            "/assistant/tool-result",
            headers={"Authorization": f"Bearer {other_token}"},
            json=result,
        ).status_code
        == 409
    )
    assert (
        client.post(
            "/assistant/tool-result", headers=headers, json={**result, "request_id": "wrong"}
        ).status_code
        == 409
    )
    assert (
        client.post(
            "/assistant/tool-result",
            headers=headers,
            json={**result, "tool_result": {"tool_name": "delete_reminder", "success": True}},
        ).status_code
        == 409
    )
    assert notes.read("audit-user", note_id) is not None
    assert client.post("/assistant/tool-result", headers=headers, json=result).status_code == 200
    assert notes.read("audit-user", note_id) is None


def test_new_query_invalidates_previous_confirmation(session):
    client, app, headers = session
    note_id = NoteService(app.state.db).save("audit-user", "Preserve", "Synthetic data")
    _model_proposal(app, "delete_note", {"note_id": note_id})
    proposal = client.post(
        "/assistant/query", headers=headers, json={"query": "remove saved item"}
    ).json()
    client.post("/assistant/query", headers=headers, json={"query": "what time is it"})
    result = {
        "request_id": proposal["request_id"],
        "tool_result": {"tool_name": "delete_note", "success": True},
    }
    assert client.post("/assistant/tool-result", headers=headers, json=result).status_code == 409
    assert NoteService(app.state.db).read("audit-user", note_id) is not None


def test_allowlisted_schedule_update_and_memory_deletion_have_real_effects(session):
    from src.ai_assistant.services.user_data import MemoryService, ScheduleService

    client, app, headers = session
    schedules = ScheduleService(app.state.db)
    entry_id = schedules.create("audit-user", "Before", "2026-10-10T10:00:00+05:00")
    _model_proposal(app, "update_schedule_entry", {"entry_id": entry_id, "title": "After"})
    response = client.post(
        "/assistant/query", headers=headers, json={"query": "change saved appointment"}
    )
    assert response.status_code == 200
    assert schedules.list("audit-user")[0]["title"] == "After"
    memories = MemoryService(app.state.db)
    memory_id = memories.save("audit-user", "Synthetic memory")
    _model_proposal(app, "forget_memory", {"memory_id": memory_id})
    proposal = client.post(
        "/assistant/query", headers=headers, json={"query": "remove saved memory"}
    ).json()
    assert len(memories.list("audit-user")) == 1
    response = client.post(
        "/assistant/tool-result",
        headers=headers,
        json={
            "request_id": proposal["request_id"],
            "tool_result": {"tool_name": "forget_memory", "success": True},
        },
    )
    assert response.status_code == 200
    assert memories.list("audit-user") == []


def test_audio_temporary_file_is_removed_on_transcription_failure(session, tmp_path, monkeypatch):
    from src.ai_assistant.routers import assistant
    from src.ai_assistant.services.transcription import TranscriptionError

    client, app, headers = session
    original = assistant.tempfile.NamedTemporaryFile
    paths = []

    def recording_tempfile(**kwargs):
        file = original(dir=tmp_path, **kwargs)
        paths.append(file.name)
        return file

    class Transcriber:
        def transcribe(self, path):
            raise TranscriptionError("Test transcription failure")

    monkeypatch.setattr(assistant.tempfile, "NamedTemporaryFile", recording_tempfile)
    app.state.transcription_provider = Transcriber()
    response = client.post(
        "/assistant/audio",
        headers=headers,
        files={"audio": ("voice.wav", _silent_wav(0.1), "audio/wav")},
    )
    assert response.status_code == 422
    from pathlib import Path

    assert len(paths) == 1
    assert not Path(paths[0]).exists()


def test_completed_reminders_are_included_only_when_requested(session):
    from src.ai_assistant.services.user_data import ReminderService

    client, app, headers = session
    reminders = ReminderService(app.state.db)
    reminder = reminders.create("audit-user", "Completed test task", "2026-10-10T10:00:00+05:00")
    reminders.complete("audit-user", reminder["id"])
    _model_proposal(app, "list_reminders", {"include_completed": True})
    response = client.post(
        "/assistant/query", headers=headers, json={"query": "show completed saved tasks"}
    )
    assert response.status_code == 200
    assert "Completed test task" in response.json()["response_text"]
