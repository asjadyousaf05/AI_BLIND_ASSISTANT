"""Integration tests for the FastAPI assistant backend.

Tests full HTTP flows: health check, pairing, text queries, tool results,
history, and authentication enforcement using a simulated AI provider.
"""

from __future__ import annotations

import io
import wave

import pytest
from fastapi.testclient import TestClient

from src.ai_assistant.config import settings
from src.ai_assistant.main import create_app


@pytest.fixture
def client(tmp_path, monkeypatch):
    db_file = tmp_path / "test_assistant.db"
    monkeypatch.setattr(settings, "db_path", db_file)
    monkeypatch.setattr(settings, "persist_conversation_history", True)
    app = create_app(
        use_simulated_ai=True,
        use_simulated_transcription=True,
    )
    with TestClient(app) as test_client:
        yield test_client, app


class TestBackendAPI:
    def test_health_endpoint(self, client):
        tc, _ = client
        res = tc.get("/health")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "ok"
        assert data["protocol_version"] == 1
        assert "ollama_available" in data
        assert data["provider"] == "simulated"
        assert data["ai_available"] is True

    def test_pair_and_query_flow(self, client):
        tc, app = client
        auth_svc = app.state.auth_service

        # Generate pairing code
        code = auth_svc.generate_pairing_code("user_test", "TestUser")

        # Pair
        pair_res = tc.post(
            "/auth/pair",
            json={"pairing_code": code},
        )
        assert pair_res.status_code == 200
        pair_data = pair_res.json()
        token = pair_data["token"]
        assert token
        assert pair_data["user_id"] == "user_test"

        headers = {"Authorization": f"Bearer {token}"}

        # Text query — time query
        query_res = tc.post(
            "/assistant/query",
            headers=headers,
            json={"query": "What time is it?", "history": []},
        )
        assert query_res.status_code == 200
        query_data = query_res.json()
        assert "response_text" in query_data
        assert "request_id" in query_data

    def test_unauthenticated_query_rejected(self, client):
        tc, _ = client
        res = tc.post(
            "/assistant/query",
            json={"query": "Hello", "history": []},
        )
        assert res.status_code == 401

    def test_invalid_bearer_token_rejected(self, client):
        tc, _ = client
        headers = {"Authorization": "Bearer badtoken123"}
        res = tc.post(
            "/assistant/query",
            headers=headers,
            json={"query": "Hello", "history": []},
        )
        assert res.status_code == 401

    def test_mobile_tool_call_flow(self, client):
        tc, app = client
        auth_svc = app.state.auth_service
        code = auth_svc.generate_pairing_code("user_rem", "RemUser")
        _, token, _ = auth_svc.pair(code)
        headers = {"Authorization": f"Bearer {token}"}

        # Query — prompt asking to start mobile mode
        res = tc.post(
            "/assistant/query",
            headers=headers,
            json={"query": "Start mobile mode", "history": []},
        )
        assert res.status_code == 200
        data = res.json()
        assert "response_text" in data
        req_id = data["request_id"]

        # Report mobile tool execution result back
        result_res = tc.post(
            "/assistant/tool-result",
            headers=headers,
            json={
                "request_id": req_id,
                "tool_result": {
                    "tool_name": "start_mobile_mode",
                    "success": True,
                    "result_data": {"state": "active"},
                },
                "history": [],
            },
        )
        assert result_res.status_code == 200
        assert result_res.json()["response_text"] == "Mobile Mode started."
        result_data = result_res.json()
        assert "response_text" in result_data

    def test_history_crud(self, client):
        tc, app = client
        auth_svc = app.state.auth_service
        code = auth_svc.generate_pairing_code("user_hist", "HistUser")
        _, token, _ = auth_svc.pair(code)
        headers = {"Authorization": f"Bearer {token}"}

        # Send query
        tc.post(
            "/assistant/query",
            headers=headers,
            json={"query": "Hello AI", "history": []},
        )

        # Get history
        hist_res = tc.get("/assistant/history", headers=headers)
        assert hist_res.status_code == 200
        messages = hist_res.json()["messages"]
        assert len(messages) >= 2  # 1 user, 1 assistant

        # Delete history
        del_res = tc.delete("/assistant/history", headers=headers)
        assert del_res.status_code == 204

        # Confirm history empty
        hist_res2 = tc.get("/assistant/history", headers=headers)
        assert len(hist_res2.json()["messages"]) == 0

    def test_list_reminders_and_notes(self, client):
        tc, app = client
        auth_svc = app.state.auth_service
        code = auth_svc.generate_pairing_code("user_data", "DataUser")
        _, token, _ = auth_svc.pair(code)
        headers = {"Authorization": f"Bearer {token}"}

        rem_res = tc.get("/assistant/reminders", headers=headers)
        assert rem_res.status_code == 200
        assert "reminders" in rem_res.json()

        notes_res = tc.get("/assistant/notes", headers=headers)
        assert notes_res.status_code == 200
        assert "notes" in notes_res.json()

    def test_daily_summary(self, client):
        tc, app = client
        auth_svc = app.state.auth_service
        code = auth_svc.generate_pairing_code("user_ds", "SummaryUser")
        _, token, _ = auth_svc.pair(code)
        headers = {"Authorization": f"Bearer {token}"}

        summary_res = tc.get("/assistant/daily-summary", headers=headers)
        assert summary_res.status_code == 200
        assert "summary" in summary_res.json()

    def test_audio_query_accepts_bounded_wav_and_uses_local_transcription(self, client):
        tc, app = client
        code = app.state.auth_service.generate_pairing_code("user_audio", "AudioUser")
        _, token, _ = app.state.auth_service.pair(code)
        headers = {"Authorization": f"Bearer {token}"}

        audio_bytes = _silent_wav(duration_seconds=0.25)
        response = tc.post(
            "/assistant/audio",
            headers=headers,
            files={"audio": ("voice.wav", audio_bytes, "audio/wav")},
            data={"history": "[]"},
        )

        assert response.status_code == 200
        assert "response_text" in response.json()

    def test_audio_query_rejects_non_audio_content_type(self, client):
        tc, app = client
        code = app.state.auth_service.generate_pairing_code("user_bad_audio", "AudioUser")
        _, token, _ = app.state.auth_service.pair(code)
        response = tc.post(
            "/assistant/audio",
            headers={"Authorization": f"Bearer {token}"},
            files={"audio": ("payload.txt", b"not audio" * 100, "text/plain")},
            data={"history": "[]"},
        )

        assert response.status_code == 415


def _silent_wav(duration_seconds: float) -> bytes:
    sample_rate = 16_000
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(b"\x00\x00" * int(sample_rate * duration_seconds))
    return buffer.getvalue()
