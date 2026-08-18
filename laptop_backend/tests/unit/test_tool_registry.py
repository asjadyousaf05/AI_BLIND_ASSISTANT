"""Unit tests for the tool registry."""

from __future__ import annotations

import json

import pytest

from src.ai_assistant.tools.registry import ToolError, ToolRegistry


class TestToolRegistryParsing:
    def test_text_only_response(self):
        raw = json.dumps({"response_text": "Hello, I can help."})
        result = ToolRegistry.parse_and_validate(raw)
        assert result.response_text == "Hello, I can help."
        assert result.tool_call is None
        assert not result.requires_confirmation

    def test_tool_call_valid(self):
        raw = json.dumps(
            {
                "response_text": "Sure, I will check the time.",
                "tool_call": {"name": "get_current_time", "arguments": {}},
                "requires_confirmation": False,
            }
        )
        result = ToolRegistry.parse_and_validate(raw)
        assert result.tool_call is not None
        assert result.tool_call["name"] == "get_current_time"
        assert not result.requires_confirmation

    def test_tool_call_with_confirmation(self):
        raw = json.dumps(
            {
                "response_text": "I will create that reminder.",
                "tool_call": {
                    "name": "create_reminder",
                    "arguments": {
                        "title": "Doctor appointment",
                        "scheduled_at": "2026-08-12T09:00:00+00:00",
                    },
                },
                "requires_confirmation": True,
                "confirmation_prompt": "Create a reminder for Doctor appointment at 9 AM?",
            }
        )
        result = ToolRegistry.parse_and_validate(raw)
        assert result.tool_call is not None
        assert result.requires_confirmation
        assert "Doctor appointment" in result.tool_call["arguments"]["title"]

    def test_unknown_tool_raises_tool_error(self):
        raw = json.dumps(
            {
                "response_text": "Executing.",
                "tool_call": {"name": "drop_database", "arguments": {}},
            }
        )
        with pytest.raises(ToolError) as exc_info:
            ToolRegistry.parse_and_validate(raw)
        assert "Unknown tool" in str(exc_info.value)

    def test_missing_required_arg_raises_tool_error(self):
        raw = json.dumps(
            {
                "response_text": "Saving note.",
                "tool_call": {
                    "name": "save_note",
                    "arguments": {"title": "Test"},  # Missing 'content'
                },
            }
        )
        with pytest.raises(ToolError) as exc_info:
            ToolRegistry.parse_and_validate(raw)
        assert "content" in str(exc_info.value)

    def test_extra_args_stripped(self):
        raw = json.dumps(
            {
                "response_text": "Getting time.",
                "tool_call": {
                    "name": "get_current_time",
                    "arguments": {
                        "injected_secret": "DROP TABLE users",
                        "extra": "ignored",
                    },
                },
            }
        )
        result = ToolRegistry.parse_and_validate(raw)
        assert result.tool_call is not None
        assert "injected_secret" not in result.tool_call["arguments"]
        assert "extra" not in result.tool_call["arguments"]

    def test_malformed_json_returns_text_fallback(self):
        raw = "Hello, I can help you with that. {broken json"
        result = ToolRegistry.parse_and_validate(raw)
        # Should not raise — returns a text response
        assert result.response_text
        assert result.tool_call is None

    def test_empty_response_fallback(self):
        result = ToolRegistry.parse_and_validate("")
        assert result.response_text
        assert result.tool_call is None

    def test_delete_note_requires_confirmation(self):
        raw = json.dumps(
            {
                "response_text": "I will delete that note.",
                "tool_call": {"name": "delete_note", "arguments": {"note_id": "abc123"}},
                "requires_confirmation": False,
            }
        )
        result = ToolRegistry.parse_and_validate(raw)
        # Spec overrides model — delete_note always requires confirmation
        assert result.requires_confirmation

    def test_server_side_tool_identification(self):
        assert ToolRegistry.is_server_side("save_note") is True
        assert ToolRegistry.is_server_side("get_current_time") is True
        assert ToolRegistry.is_server_side("get_mobile_mode_status") is False
        assert ToolRegistry.is_server_side("start_mobile_mode") is False
        assert ToolRegistry.is_server_side("get_raspberry_pi_status") is False

    def test_injection_attempt_blocked(self):
        """Model tries to execute shell — must be rejected."""
        dangerous_names = [
            "execute_shell",
            "run_command",
            "eval",
            "exec",
            "os.system",
            "subprocess",
            "__import__",
        ]
        for name in dangerous_names:
            raw = json.dumps(
                {
                    "response_text": "Executing.",
                    "tool_call": {"name": name, "arguments": {}},
                }
            )
            with pytest.raises(ToolError):
                ToolRegistry.parse_and_validate(raw)

    def test_invalid_sensitivity_value_is_rejected(self):
        raw = json.dumps(
            {
                "response_text": "Changing sensitivity.",
                "tool_call": {
                    "name": "change_detection_sensitivity",
                    "arguments": {"level": "maximum"},
                },
            }
        )
        with pytest.raises(ToolError):
            ToolRegistry.parse_and_validate(raw)

    def test_non_boolean_accessibility_value_is_rejected(self):
        raw = json.dumps(
            {
                "response_text": "Changing text size.",
                "tool_call": {
                    "name": "set_large_text_enabled",
                    "arguments": {"enabled": "yes"},
                },
            }
        )
        with pytest.raises(ToolError):
            ToolRegistry.parse_and_validate(raw)
