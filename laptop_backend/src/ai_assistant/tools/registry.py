"""Strict tool registry with allow-listing and structured validation.

The model must propose a structured JSON tool call. This module:
1. Validates the tool name against an explicit allow-list.
2. Validates required arguments and their types.
3. Never gives the model general shell, filesystem, or database access.
4. Protects against prompt-injection trying to invoke unavailable tools.
"""

from __future__ import annotations

import json
import logging
import re
import uuid

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Allow-listed tools with argument schemas
# ---------------------------------------------------------------------------


class ToolSpec:
    def __init__(
        self,
        name: str,
        required_args: list[str] | None = None,
        optional_args: list[str] | None = None,
        requires_confirmation: bool = False,
        server_side: bool = True,
    ) -> None:
        self.name = name
        self.required_args = required_args or []
        self.optional_args = optional_args or []
        self.requires_confirmation = requires_confirmation
        self.server_side = server_side  # Executed on backend vs phone


_TOOLS: dict[str, ToolSpec] = {
    t.name: t
    for t in [
        # Time
        ToolSpec("get_current_time"),
        ToolSpec("get_current_date"),
        # Notes (confirmation for destructive ops)
        ToolSpec("save_note", required_args=["title", "content"]),
        ToolSpec("list_notes"),
        ToolSpec("read_note", required_args=["note_id"]),
        ToolSpec("delete_note", required_args=["note_id"], requires_confirmation=True),
        # Reminders
        ToolSpec(
            "create_reminder",
            required_args=["title", "scheduled_at"],
            optional_args=["note", "timezone"],
        ),
        ToolSpec("list_reminders", optional_args=["include_completed"]),
        ToolSpec("complete_reminder", required_args=["reminder_id"]),
        ToolSpec("delete_reminder", required_args=["reminder_id"], requires_confirmation=True),
        # Schedule
        ToolSpec(
            "create_schedule_entry",
            required_args=["title", "starts_at"],
            optional_args=["ends_at", "description", "timezone"],
        ),
        ToolSpec("list_schedule"),
        ToolSpec(
            "update_schedule_entry",
            required_args=["entry_id"],
            optional_args=["title", "starts_at", "ends_at", "description"],
        ),
        ToolSpec("delete_schedule_entry", required_args=["entry_id"], requires_confirmation=True),
        # Preferences / memory
        ToolSpec("save_preference", required_args=["key", "value"]),
        ToolSpec("recall_preference", required_args=["key"]),
        ToolSpec("forget_memory", required_args=["memory_id"], requires_confirmation=True),
        # Mobile Mode (executed on phone)
        ToolSpec("get_mobile_mode_status", server_side=False),
        ToolSpec("start_mobile_mode", server_side=False, requires_confirmation=True),
        ToolSpec("pause_mobile_mode", server_side=False),
        ToolSpec("resume_mobile_mode", server_side=False),
        ToolSpec("stop_mobile_mode", server_side=False),
        # App settings (executed on phone)
        ToolSpec("get_app_settings", server_side=False),
        ToolSpec(
            "change_feedback_mode",
            required_args=["mode"],
            server_side=False,
            requires_confirmation=True,
        ),
        ToolSpec(
            "set_vibration_enabled",
            required_args=["enabled"],
            server_side=False,
            requires_confirmation=True,
        ),
        ToolSpec(
            "set_high_contrast_enabled",
            required_args=["enabled"],
            server_side=False,
            requires_confirmation=True,
        ),
        ToolSpec(
            "set_large_text_enabled",
            required_args=["enabled"],
            server_side=False,
            requires_confirmation=True,
        ),
        ToolSpec(
            "set_reduced_motion_enabled",
            required_args=["enabled"],
            server_side=False,
            requires_confirmation=True,
        ),
        ToolSpec(
            "set_announcement_cooldown",
            required_args=["seconds"],
            server_side=False,
            requires_confirmation=True,
        ),
        # Raspberry Pi (executed on phone)
        ToolSpec("get_raspberry_pi_status", server_side=False),
        ToolSpec("discover_raspberry_pi", server_side=False),
        ToolSpec("connect_raspberry_pi", server_side=False, requires_confirmation=True),
        ToolSpec("disconnect_raspberry_pi", server_side=False, requires_confirmation=True),
        ToolSpec("start_wearable_assistance", server_side=False, requires_confirmation=True),
        ToolSpec("pause_wearable_assistance", server_side=False),
        ToolSpec("resume_wearable_assistance", server_side=False),
        ToolSpec("stop_wearable_assistance", server_side=False),
        # Detection
        ToolSpec(
            "change_detection_sensitivity",
            required_args=["level"],
            server_side=False,
            requires_confirmation=True,
        ),
        ToolSpec("read_recent_detections", server_side=False),
        # Assistant
        ToolSpec("get_assistant_connection_status", server_side=False),
        ToolSpec("provide_daily_summary"),
        # Document OCR (executed on phone)
        ToolSpec("trigger_ocr_scan", server_side=False),
        ToolSpec("ocr_read_again", server_side=False),
        ToolSpec("ocr_rescan", server_side=False),
        # Screen navigation & speech control (executed on phone)
        ToolSpec("navigate_to_screen", required_args=["screen"], server_side=False),
        ToolSpec("stop_speaking", server_side=False),
        ToolSpec("dismiss_assistant", server_side=False),
        # Device status & speech rate
        ToolSpec("get_battery_status", server_side=False),
        ToolSpec("set_flashlight_enabled", required_args=["enabled"], server_side=False),
        ToolSpec("set_speech_rate", required_args=["rate"], server_side=False),
        ToolSpec("stop_everything", server_side=False),
    ]
}


# ---------------------------------------------------------------------------
# Parsed response from the model
# ---------------------------------------------------------------------------


class ParsedModelResponse:
    def __init__(
        self,
        response_text: str,
        request_id: str,
        tool_call: dict | None = None,
        requires_confirmation: bool = False,
        confirmation_prompt: str | None = None,
    ) -> None:
        self.response_text = response_text
        self.request_id = request_id
        self.tool_call = tool_call
        self.requires_confirmation = requires_confirmation
        self.confirmation_prompt = confirmation_prompt


# ---------------------------------------------------------------------------
# Parser and validator
# ---------------------------------------------------------------------------


class ToolRegistry:
    @staticmethod
    def parse_and_validate(raw_content: str) -> ParsedModelResponse:
        """Parse the model's JSON output and validate any tool call.

        Raises ToolError on unknown tools, missing args, or invalid format.
        Protects against prompt injection by rejecting unknown tool names.
        """
        request_id = str(uuid.uuid4())

        # Extract JSON from model output (handle extra text before/after)
        json_match = re.search(r"\{.*\}", raw_content, re.DOTALL)
        if not json_match:
            # No JSON — treat entire output as response text
            return ParsedModelResponse(
                response_text=raw_content.strip()[:1024] or "I'm not sure how to respond.",
                request_id=request_id,
            )

        try:
            data = json.loads(json_match.group())
        except json.JSONDecodeError:
            return ParsedModelResponse(
                response_text=raw_content.strip()[:512] or "I'm not sure how to respond.",
                request_id=request_id,
            )

        response_text = str(data.get("response_text", "")).strip()[:2048]
        tool_call_data = data.get("tool_call")
        requires_confirmation = bool(data.get("requires_confirmation", False))
        confirmation_prompt = data.get("confirmation_prompt")

        if tool_call_data is None:
            return ParsedModelResponse(
                response_text=response_text or "I'm not sure how to respond.",
                request_id=request_id,
            )

        # Validate tool call
        if not isinstance(tool_call_data, dict):
            raise ToolError("Tool call must be an object.")
        tool_name = tool_call_data.get("name", "")
        arguments = tool_call_data.get("arguments", {})
        if not isinstance(arguments, dict):
            raise ToolError(f"Tool '{tool_name}' arguments must be an object.")

        if tool_name not in _TOOLS:
            raise ToolError(f"Unknown tool '{tool_name}'. Only allow-listed tools may be called.")

        spec = _TOOLS[tool_name]

        # Validate required arguments
        missing = [k for k in spec.required_args if k not in arguments]
        if missing:
            raise ToolError(f"Tool '{tool_name}' is missing required arguments: {missing}")

        # Strip unexpected arguments to prevent injection
        allowed_keys = set(spec.required_args + spec.optional_args)
        sanitized_args = {k: v for k, v in arguments.items() if k in allowed_keys}
        _validate_argument_values(tool_name, sanitized_args)

        # Confirmation: tool spec overrides model if it requires it
        if spec.requires_confirmation:
            requires_confirmation = True

        return ParsedModelResponse(
            response_text=response_text or f"I can {tool_name.replace('_', ' ')}.",
            request_id=request_id,
            tool_call={"name": tool_name, "arguments": sanitized_args},
            requires_confirmation=requires_confirmation,
            confirmation_prompt=confirmation_prompt,
        )

    @staticmethod
    def is_server_side(tool_name: str) -> bool:
        spec = _TOOLS.get(tool_name)
        return spec.server_side if spec else False


class ToolError(Exception):
    pass


def _validate_argument_values(tool_name: str, arguments: dict) -> None:
    if tool_name == "change_detection_sensitivity" and arguments.get("level") not in {
        "low",
        "medium",
        "high",
    }:
        raise ToolError("Detection sensitivity must be low, medium, or high.")
    if tool_name == "change_feedback_mode" and arguments.get("mode") not in {
        "audio",
        "vibration",
        "both",
        "audio_and_vibration",
    }:
        raise ToolError("Feedback mode must be audio, vibration, or both.")
    if (
        tool_name.startswith("set_")
        and tool_name.endswith("_enabled")
        and not isinstance(arguments.get("enabled"), bool)
    ):
        raise ToolError(f"Tool '{tool_name}' enabled must be a boolean.")
    if tool_name == "set_announcement_cooldown":
        seconds = arguments.get("seconds")
        if (
            isinstance(seconds, bool)
            or not isinstance(seconds, (int, float))
            or not 1 <= seconds <= 30
        ):
            raise ToolError("Announcement cooldown must be from 1 to 30 seconds.")
