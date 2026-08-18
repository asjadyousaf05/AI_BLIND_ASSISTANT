"""Pydantic schemas for API request/response validation."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------


class PairRequest(BaseModel):
    pairing_code: str = Field(default="", max_length=64)


class PairResponse(BaseModel):
    token: str
    user_id: str
    display_name: str
    protocol_version: int


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------


class HealthResponse(BaseModel):
    status: str = "ok"
    protocol_version: int
    model: str
    provider: str
    preferred_provider: str
    fallback_provider: str | None = None
    ai_available: bool
    gemini_configured: bool
    ollama_available: bool


# ---------------------------------------------------------------------------
# Conversation
# ---------------------------------------------------------------------------


class ConversationMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant|system)$")
    content: str = Field(..., max_length=4096)
    id: str | None = None


class TextQueryRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2048)
    history: list[ConversationMessage] = Field(default_factory=list, max_length=20)


class AudioQueryRequest(BaseModel):
    """Validated after multipart parsing."""

    history: list[ConversationMessage] = Field(default_factory=list, max_length=20)


# ---------------------------------------------------------------------------
# Tool call
# ---------------------------------------------------------------------------


class ToolCallSchema(BaseModel):
    name: str = Field(..., min_length=1, max_length=64)
    arguments: dict[str, Any] = Field(default_factory=dict)


class AssistantResponseSchema(BaseModel):
    response_text: str
    request_id: str
    tool_call: ToolCallSchema | None = None
    requires_confirmation: bool = False
    confirmation_prompt: str | None = None


class ToolResultSchema(BaseModel):
    tool_name: str
    success: bool
    result_data: dict[str, Any] | None = None
    error_message: str | None = None


class ToolResultRequest(BaseModel):
    request_id: str
    tool_result: ToolResultSchema
    history: list[ConversationMessage] = Field(default_factory=list, max_length=20)


# ---------------------------------------------------------------------------
# Reminders
# ---------------------------------------------------------------------------


class ReminderItem(BaseModel):
    id: str
    title: str
    note: str | None = None
    scheduled_at: str
    timezone: str = "UTC"
    completed: bool = False
    created_at: str


class RemindersResponse(BaseModel):
    reminders: list[ReminderItem]


# ---------------------------------------------------------------------------
# Notes
# ---------------------------------------------------------------------------


class NoteItem(BaseModel):
    id: str
    title: str
    content: str
    created_at: str


class NotesResponse(BaseModel):
    notes: list[NoteItem]


# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------


class HistoryMessage(BaseModel):
    id: str
    role: str
    content: str
    tool_name: str | None = None
    created_at: str


class HistoryResponse(BaseModel):
    messages: list[HistoryMessage]


# ---------------------------------------------------------------------------
# Daily summary
# ---------------------------------------------------------------------------


class DailySummaryResponse(BaseModel):
    summary: str
