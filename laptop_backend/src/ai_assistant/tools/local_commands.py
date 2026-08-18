"""Deterministic routing for common app-control phrases.

These commands do not need Gemini or Ollama. The registry still validates the
tool name, arguments, and confirmation policy before anything reaches Flutter.
"""

from __future__ import annotations

import json
import re

from .registry import ParsedModelResponse, ToolRegistry


def match_local_command(query: str) -> ParsedModelResponse | None:
    normalized = " ".join(query.lower().strip().split())
    if not normalized:
        return None

    settings_match = _match_settings(normalized)
    if settings_match:
        return _validated(*settings_match)

    # Screen navigation
    nav_screens = {
        "home": ["go home", "open home", "go to home", "navigate home", "show home", "home screen", "main screen"],
        "settings": ["open settings", "go to settings", "open the settings", "navigate to settings", "show settings"],
        "modes": ["select mode", "choose mode", "mode selection", "go to modes", "open modes", "modes screen"],
        "raspberry_pi": ["open raspberry pi", "open pi", "pi screen", "wearable screen"],
        "safety": ["open safety", "about safety", "safety screen", "safety info", "show safety"],
        "help": ["open help", "go to help", "help screen", "show help", "user guide", "instructions"],
        "ocr_scanner": ["open ocr", "open scanner", "open document scanner", "ocr screen", "scanner screen"],
        "back": ["go back", "navigate back", "go to previous", "previous screen", "return back"],
    }
    for screen, phrases in nav_screens.items():
        if any(p in normalized for p in phrases):
            return _validated("navigate_to_screen", {"screen": screen}, f"Opening {screen.replace('_', ' ')}.")

    # Document OCR
    if _has_any(
        normalized,
        "scan again",
        "scan another",
        "scan another document",
        "scan another page",
        "rescan",
        "try again",
        "another page",
        "new scan",
    ):
        return _validated(
            "ocr_rescan",
            {},
            "Ready to scan again. Point your camera at the document and say scan.",
        )

    if _has_any(
        normalized,
        "scan document",
        "scan the document",
        "start scan",
        "start scanning",
        "start scanner",
        "take picture and scan",
        "take photo and scan",
        "take picture",
        "take photo",
        "take a picture",
        "take a photo",
        "read document",
        "read the document",
        "read this document",
        "read this page",
        "read the page",
        "read page",
        "read text",
        "scan page",
        "scan text",
        "scan now",
        "scan it",
        "capture and scan",
        "capture picture",
        "capture photo",
        "capture document",
        "capture page",
        "capture text",
        "capture image",
        "capture now",
        "capture",
        "scan",
    ):
        return _validated("trigger_ocr_scan", {}, "Capturing and scanning document.")

    if _has_any(
        normalized,
        "read again",
        "read text again",
        "read document again",
        "repeat text",
        "repeat document",
        "read it again",
    ):
        return _validated("ocr_read_again", {}, "Reading text again.")

    if _has_any(
        normalized,
        "stop speaking",
        "stop reading",
        "be quiet",
        "silence",
    ):
        return _validated("stop_speaking", {}, "Stopping speech.")

    if _has_any(
        normalized,
        "bye vision ai",
        "bye vision",
        "goodbye vision",
        "goodbye",
        "bye",
        "stop listening",
        "dismiss",
        "go to sleep",
        "exit assistant",
        "never mind",
        "that is all",
        "that's all",
        "thanks bye",
    ):
        return _validated("dismiss_assistant", {}, "Goodbye.")

    if _has_any(
        normalized,
        "what do you see",
        "what is nearby",
        "what's nearby",
        "recent detections",
        "detected objects",
    ):
        return _validated(
            "read_recent_detections",
            {},
            "Checking the latest on-device detections.",
        )

    wearable_target = (
        _has_any(normalized, "raspberry pi", "raspberry", "wearable", "smart cap")
        or re.search(r"\bpi\b", normalized) is not None
    )
    mobile_target = _has_any(
        normalized,
        "mobile mode",
        "mobile detection",
        "mobile assistance",
        "phone mode",
        "phone detection",
    )

    if wearable_target:
        if _has_any(normalized, "status", "state", "connected"):
            return _validated("get_raspberry_pi_status", {}, "Checking wearable status.")
        if _has_any(normalized, "scan", "find", "discover", "search"):
            return _validated("discover_raspberry_pi", {}, "Searching for your wearable.")
        if "disconnect" in normalized:
            return _validated("disconnect_raspberry_pi", {}, "I can disconnect the wearable.")
        if "connect" in normalized:
            return _validated("connect_raspberry_pi", {}, "I can connect the wearable.")
        if _has_any(normalized, "pause", "hold"):
            return _validated("pause_wearable_assistance", {}, "Pausing wearable assistance.")
        if _has_any(normalized, "resume", "continue"):
            return _validated("resume_wearable_assistance", {}, "Resuming wearable assistance.")
        if (
            _has_any(normalized, "stop", "end", "turn off", "disable")
            or _enabled_value(normalized) is False
        ):
            return _validated("stop_wearable_assistance", {}, "Stopping wearable assistance.")
        if (
            _has_any(normalized, "start", "run", "begin", "turn on", "enable")
            or _enabled_value(normalized) is True
        ):
            return _validated("start_wearable_assistance", {}, "I can start wearable assistance.")

    if mobile_target:
        if _has_any(normalized, "status", "state", "running"):
            return _validated("get_mobile_mode_status", {}, "Checking Mobile Mode status.")
        if _has_any(normalized, "pause", "hold"):
            return _validated("pause_mobile_mode", {}, "Pausing Mobile Mode.")
        if _has_any(normalized, "resume", "continue"):
            return _validated("resume_mobile_mode", {}, "Resuming Mobile Mode.")
        if (
            _has_any(normalized, "stop", "end", "turn off", "disable")
            or _enabled_value(normalized) is False
        ):
            return _validated("stop_mobile_mode", {}, "Stopping Mobile Mode.")
        if (
            _has_any(normalized, "start", "run", "begin", "turn on", "enable")
            or _enabled_value(normalized) is True
        ):
            return _validated("start_mobile_mode", {}, "I can start Mobile Mode.")

    if _has_any(normalized, "assistant status", "assistant connection"):
        return _validated("get_assistant_connection_status", {}, "Checking assistant connection.")
    return None


def _match_settings(normalized: str) -> tuple[str, dict, str] | None:
    if _has_any(normalized, "read settings", "current settings", "settings status"):
        return "get_app_settings", {}, "Reading the current app settings."

    if "sensitivity" in normalized:
        if _has_any(normalized, "low", "reduce", "decrease", "less"):
            level = "low"
        elif _has_any(normalized, "high", "increase", "more"):
            level = "high"
        elif _has_any(normalized, "medium", "normal", "default"):
            level = "medium"
        else:
            return None
        return (
            "change_detection_sensitivity",
            {"level": level},
            f"I can set detection sensitivity to {level}.",
        )

    if "feedback" in normalized:
        if "vibration" in normalized and _has_any(normalized, "audio", "speech", "both"):
            mode = "both"
        elif "vibration" in normalized:
            mode = "vibration"
        elif _has_any(normalized, "audio", "speech"):
            mode = "audio"
        else:
            return None
        return (
            "change_feedback_mode",
            {"mode": mode},
            f"I can change feedback mode to {mode}.",
        )

    boolean_settings = {
        "high contrast": "set_high_contrast_enabled",
        "large text": "set_large_text_enabled",
        "reduced motion": "set_reduced_motion_enabled",
        "vibration": "set_vibration_enabled",
    }
    for phrase, tool in boolean_settings.items():
        if phrase not in normalized:
            continue
        enabled = _enabled_value(normalized)
        if enabled is None:
            return None
        state = "on" if enabled else "off"
        return tool, {"enabled": enabled}, f"I can turn {phrase} {state}."

    # Emergency Stop
    if _has_any(
        normalized,
        "stop everything",
        "stop all",
        "emergency stop",
        "halt everything",
        "halt",
    ):
        return "stop_everything", {}, "Stopping all assistance and audio."

    # Battery Query
    if _has_any(
        normalized,
        "battery level",
        "battery status",
        "battery percentage",
        "what is my battery",
        "how much battery",
        "check battery",
        "battery",
    ):
        return "get_battery_status", {}, "Checking battery status."

    # Flashlight / Torch
    if _has_any(normalized, "flashlight", "torch"):
        enabled = _enabled_value(normalized)
        if enabled is not None:
            return (
                "set_flashlight_enabled",
                {"enabled": enabled},
                f"Turning {'on' if enabled else 'off'} flashlight.",
            )

    # Speech Rate / Speed
    if _has_any(
        normalized,
        "speak faster",
        "faster speech",
        "faster voice",
        "increase speech rate",
        "speed up voice",
    ):
        return "set_speech_rate", {"rate": "fast"}, "Increasing speech rate."

    if _has_any(
        normalized,
        "speak slower",
        "slower speech",
        "slower voice",
        "decrease speech rate",
        "slow down voice",
    ):
        return "set_speech_rate", {"rate": "slow"}, "Decreasing speech rate."

    if _has_any(
        normalized,
        "normal speech rate",
        "normal voice",
        "reset speech rate",
        "reset voice speed",
    ):
        return "set_speech_rate", {"rate": "normal"}, "Setting speech rate to normal."

    if "cooldown" in normalized or "announcement interval" in normalized:
        seconds = _parse_number(normalized)
        if seconds is not None and 1 <= seconds <= 30:
            return (
                "set_announcement_cooldown",
                {"seconds": seconds},
                f"I can set the announcement cooldown to {seconds} seconds.",
            )
    return None


def _parse_number(text: str) -> int | None:
    word_map = {
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
        "ten": 10,
        "fifteen": 15,
        "twenty": 20,
        "twenty five": 25,
        "thirty": 30,
    }
    for word, val in word_map.items():
        if re.search(rf"\b{word}\b", text):
            return val
    match = re.search(r"\b([1-9]|[12][0-9]|30)\b", text)
    if match:
        return int(match.group(1))
    return None


def _validated(name: str, arguments: dict, response_text: str) -> ParsedModelResponse:
    return ToolRegistry.parse_and_validate(
        json.dumps(
            {
                "response_text": response_text,
                "tool_call": {"name": name, "arguments": arguments},
            }
        )
    )


def _enabled_value(text: str) -> bool | None:
    if re.search(r"\b(disable|disabled|off)\b", text) or "turn off" in text:
        return False
    if re.search(r"\b(enable|enabled|on)\b", text) or "turn on" in text:
        return True
    return None


def _has_any(text: str, *phrases: str) -> bool:
    return any(phrase in text for phrase in phrases)

