from __future__ import annotations

import pytest

from src.ai_assistant.tools.local_commands import match_local_command


@pytest.mark.parametrize(
    ("phrase", "tool_name", "arguments", "confirmation"),
    [
        (
            "reduce sensitivity",
            "change_detection_sensitivity",
            {"level": "low"},
            True,
        ),
        ("start mobile mode", "start_mobile_mode", {}, True),
        ("turn the mobile mode detection on", "start_mobile_mode", {}, True),
        ("turn mobile mode off", "stop_mobile_mode", {}, False),
        ("pause mobile assistance", "pause_mobile_mode", {}, False),
        ("find my raspberry pi", "discover_raspberry_pi", {}, False),
        ("connect the wearable", "connect_raspberry_pi", {}, True),
        (
            "turn on high contrast",
            "set_high_contrast_enabled",
            {"enabled": True},
            True,
        ),
        (
            "turn off vibration",
            "set_vibration_enabled",
            {"enabled": False},
            True,
        ),
        (
            "set feedback to audio and vibration",
            "change_feedback_mode",
            {"mode": "both"},
            True,
        ),
        (
            "set announcement cooldown to 8 seconds",
            "set_announcement_cooldown",
            {"seconds": 8},
            True,
        ),
        (
            "set announcement cooldown to five seconds",
            "set_announcement_cooldown",
            {"seconds": 5},
            True,
        ),
        ("what do you see", "read_recent_detections", {}, False),
        ("scan document", "trigger_ocr_scan", {}, False),
        ("start scan", "trigger_ocr_scan", {}, False),
        ("open scanner", "navigate_to_screen", {"screen": "ocr_scanner"}, False),
        ("scan again", "ocr_rescan", {}, False),
        ("read again", "ocr_read_again", {}, False),
        ("stop speaking", "stop_speaking", {}, False),
        ("bye vision ai", "dismiss_assistant", {}, False),
        ("open settings", "navigate_to_screen", {"screen": "settings"}, False),
        ("open safety", "navigate_to_screen", {"screen": "safety"}, False),
        ("open help", "navigate_to_screen", {"screen": "help"}, False),
        ("battery status", "get_battery_status", {}, False),
        ("turn on flashlight", "set_flashlight_enabled", {"enabled": True}, False),
        ("speak faster", "set_speech_rate", {"rate": "fast"}, False),
        ("stop everything", "stop_everything", {}, False),
    ],
)
def test_common_control_phrases_are_deterministic(phrase, tool_name, arguments, confirmation):
    result = match_local_command(phrase)

    assert result is not None
    assert result.tool_call == {"name": tool_name, "arguments": arguments}
    assert result.requires_confirmation is confirmation


def test_general_conversation_is_left_for_ai_provider():
    assert match_local_command("Tell me a short story") is None


def test_ambiguous_application_phrase_does_not_trigger_wearable():
    assert match_local_command("start the application") is None
