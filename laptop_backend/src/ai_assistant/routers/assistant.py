"""Main assistant router — text query, audio query, tool result, history, summaries."""

from __future__ import annotations

import json
import logging
import os
import tempfile
from datetime import UTC
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from starlette.concurrency import run_in_threadpool

from ..models.schemas import (
    AssistantResponseSchema,
    DailySummaryResponse,
    HistoryResponse,
    NotesResponse,
    RemindersResponse,
    TextQueryRequest,
    ToolCallSchema,
    ToolResultRequest,
)
from ..services.ai_provider import AIProviderError
from ..services.transcription import TranscriptionError
from ..services.user_data import (
    AuditService,
    ConversationService,
    NoteService,
    PreferenceService,
    ReminderService,
    ScheduleService,
)
from ..tools.local_commands import match_local_command
from ..tools.registry import ParsedModelResponse, ToolError, ToolRegistry
from .deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/assistant", tags=["assistant"])

_MAX_AUDIO_BYTES = 4 * 1024 * 1024
_MAX_AUDIO_SECONDS = 30.5
_ALLOWED_AUDIO_TYPES = {
    "audio/m4a",
    "audio/mp4",
    "audio/x-m4a",
    "audio/wav",
    "audio/x-wav",
    "audio/aac",
    "audio/x-aac",
    "audio/3gpp",
    "audio/ogg",
    "audio/webm",
    "audio/mpeg",
    "application/octet-stream",
}


# ---------------------------------------------------------------------------
# Text query
# ---------------------------------------------------------------------------


@router.post("/query", response_model=AssistantResponseSchema)
async def text_query(
    body: TextQueryRequest,
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
) -> AssistantResponseSchema:
    """Process a text query from the user."""
    ai_provider = req.app.state.ai_provider
    conversation_svc = ConversationService(req.app.state.db)
    audit_svc = AuditService(req.app.state.db)

    history = [{"role": m.role, "content": m.content} for m in body.history]

    parsed = match_local_command(body.query)
    provider_label = "deterministic"
    model_label = "local-command-router"
    if parsed is None:
        try:
            ai_response = await ai_provider.generate(
                prompt=body.query.strip(),
                history=history,
            )
            provider_label = ai_response.provider
            model_label = ai_response.model
        except AIProviderError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="The configured AI providers are unavailable. Start Ollama or check Gemini.",
            )

        try:
            parsed = ToolRegistry.parse_and_validate(ai_response.content)
        except ToolError as e:
            logger.warning(
                "Tool validation rejected a model response: %s",
                type(e).__name__,
            )
            extracted_text = ""
            try:
                data = json.loads(ai_response.content)
                if isinstance(data, dict):
                    extracted_text = str(data.get("response_text", "")).strip()
            except Exception:
                pass
            if not extracted_text:
                extracted_text = ai_response.content.strip()

            parsed = ParsedModelResponse(
                response_text=extracted_text[:1024] if (extracted_text and len(extracted_text) > 3) else "I'm sorry, I can't perform that action.",
                request_id="",
            )

    # Execute server-side tools
    if parsed.tool_call and ToolRegistry.is_server_side(parsed.tool_call["name"]):
        result_text = await _execute_server_tool(parsed.tool_call, user_id, req)
        if result_text:
            parsed.response_text = result_text
            parsed.tool_call = None  # Don't forward to phone

    # Persist conversation
    if req.app.state.settings.persist_conversation_history:
        conversation_svc.append(user_id, "user", body.query)
        conversation_svc.append(user_id, "assistant", parsed.response_text)
    audit_svc.log(
        user_id,
        "text_query",
        f"provider={provider_label};model={model_label}",
    )

    return AssistantResponseSchema(
        response_text=parsed.response_text,
        request_id=parsed.request_id,
        tool_call=ToolCallSchema(**parsed.tool_call)
        if parsed.tool_call and not ToolRegistry.is_server_side(parsed.tool_call["name"])
        else None,
        requires_confirmation=parsed.requires_confirmation,
        confirmation_prompt=parsed.confirmation_prompt,
    )


# ---------------------------------------------------------------------------
# Audio query
# ---------------------------------------------------------------------------


@router.post("/audio", response_model=AssistantResponseSchema)
async def audio_query(
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
    audio: Annotated[UploadFile, File()],
    history: Annotated[str, Form()] = "[]",
) -> AssistantResponseSchema:
    """Accept an audio upload, transcribe it, and return an AI response."""
    content_type = (audio.content_type or "").lower()
    filename = (audio.filename or "").lower()
    is_valid_type = (
        content_type in _ALLOWED_AUDIO_TYPES
        or filename.endswith((".m4a", ".wav", ".aac", ".mp3", ".ogg", ".webm", ".3gp"))
    )
    if not is_valid_type:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Audio must be an M4A or WAV recording.",
        )
    # Validate content size
    content = await audio.read()
    if len(content) > _MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Audio file exceeds maximum size (4 MB).",
        )
    if len(content) < 256:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Audio file is too small — likely empty or silent.",
        )

    # Parse history
    try:
        parsed_history = json.loads(history) if history else []
    except json.JSONDecodeError:
        parsed_history = []

    # Write to temp file
    orig_ext = os.path.splitext(audio.filename or "")[1].lower()
    suffix = orig_ext if orig_ext in {".m4a", ".wav", ".aac", ".mp4", ".ogg", ".webm", ".3gp", ".mp3"} else ".m4a"
    tmp_path: str
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(content)
        tmp.flush()
        tmp_path = tmp.name

    try:
        duration_seconds = await run_in_threadpool(_audio_duration_seconds, tmp_path)
        if duration_seconds > _MAX_AUDIO_SECONDS:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Audio recording exceeds the 30 second limit.",
            )

        # Transcribe
        transcription_svc = req.app.state.transcription_provider
        try:
            transcript = await run_in_threadpool(transcription_svc.transcribe, tmp_path)
        except TranscriptionError as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Transcription failed: {e}",
            )

    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    # Delegate to text query logic
    from ..models.schemas import ConversationMessage

    text_body = TextQueryRequest(
        query=transcript,
        history=[
            ConversationMessage(role=m["role"], content=m["content"])
            for m in parsed_history
            if isinstance(m, dict) and "role" in m and "content" in m
        ],
    )

    return await text_query(text_body, req, user_id)


def _audio_duration_seconds(audio_path: str) -> float:
    try:
        import av

        with av.open(audio_path) as container:
            if container.duration is not None and container.duration > 0:
                return float(container.duration / av.time_base)
            audio_stream = next(
                (stream for stream in container.streams if stream.type == "audio"),
                None,
            )
            if (
                audio_stream is not None
                and audio_stream.duration is not None
                and audio_stream.time_base is not None
            ):
                return float(audio_stream.duration * audio_stream.time_base)
            if audio_stream is not None:
                return 5.0
    except Exception:
        try:
            size = os.path.getsize(audio_path)
            if 256 <= size <= _MAX_AUDIO_BYTES:
                return 5.0
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="The audio recording is invalid or unreadable.",
        )
    return 5.0


# ---------------------------------------------------------------------------
# Tool result
# ---------------------------------------------------------------------------


@router.post("/tool-result", response_model=AssistantResponseSchema)
async def tool_result(
    body: ToolResultRequest,
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
) -> AssistantResponseSchema:
    """Accept a phone result and produce a local deterministic follow-up."""
    conversation_svc = ConversationService(req.app.state.db)
    audit_svc = AuditService(req.app.state.db)

    result = body.tool_result
    response_text = _format_phone_tool_result(result)

    if req.app.state.settings.persist_conversation_history:
        conversation_svc.append(
            user_id,
            "assistant",
            response_text,
            tool_name=result.tool_name,
        )
    audit_svc.log(user_id, "tool_result", result.tool_name)

    return AssistantResponseSchema(
        response_text=response_text,
        request_id=body.request_id,
    )


def _format_phone_tool_result(result) -> str:
    friendly_names = {
        "start_mobile_mode": "Mobile Mode started.",
        "pause_mobile_mode": "Mobile Mode paused.",
        "resume_mobile_mode": "Mobile Mode resumed.",
        "stop_mobile_mode": "Mobile Mode stopped.",
        "change_detection_sensitivity": "Detection sensitivity updated.",
        "change_feedback_mode": "Feedback mode updated.",
        "connect_raspberry_pi": "Raspberry Pi connected.",
        "disconnect_raspberry_pi": "Raspberry Pi disconnected.",
        "start_wearable_assistance": "Wearable assistance started.",
        "pause_wearable_assistance": "Wearable assistance paused.",
        "resume_wearable_assistance": "Wearable assistance resumed.",
        "stop_wearable_assistance": "Wearable assistance stopped.",
    }
    if not result.success:
        detail = (result.error_message or "The requested action failed.")[:300]
        return f"I couldn't complete that action. {detail}"
    if result.tool_name == "read_recent_detections":
        data = result.result_data or {}
        objects = data.get("objects", [])
        labels = [
            str(item.get("label", "object"))[:80] for item in objects[:5] if isinstance(item, dict)
        ]
        if not labels:
            return "There are no stable on-device detections right now."
        return f"The latest on-device detections are: {', '.join(labels)}."
    return friendly_names.get(result.tool_name, "Done.")


# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------


@router.get("/history", response_model=HistoryResponse)
async def get_history(
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
    limit: int = 20,
) -> HistoryResponse:
    from ..models.schemas import HistoryMessage

    svc = ConversationService(req.app.state.db)
    messages = svc.list(user_id, limit=min(limit, 50))
    return HistoryResponse(
        messages=[
            HistoryMessage(
                id=m["id"],
                role=m["role"],
                content=m["content"],
                tool_name=m.get("tool_name"),
                created_at=m["created_at"],
            )
            for m in messages
        ]
    )


@router.delete("/history", status_code=status.HTTP_204_NO_CONTENT)
async def delete_history(
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
) -> None:
    svc = ConversationService(req.app.state.db)
    svc.clear(user_id)


# ---------------------------------------------------------------------------
# Reminders
# ---------------------------------------------------------------------------


@router.get("/reminders", response_model=RemindersResponse)
async def list_reminders(
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
) -> RemindersResponse:
    from ..models.schemas import ReminderItem

    svc = ReminderService(req.app.state.db)
    items = svc.list(user_id)
    return RemindersResponse(reminders=[ReminderItem(**r) for r in items])


# ---------------------------------------------------------------------------
# Notes
# ---------------------------------------------------------------------------


@router.get("/notes", response_model=NotesResponse)
async def list_notes(
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
) -> NotesResponse:
    from ..models.schemas import NoteItem

    svc = NoteService(req.app.state.db)
    items = svc.list(user_id)
    return NotesResponse(notes=[NoteItem(**n) for n in items])


# ---------------------------------------------------------------------------
# Daily summary
# ---------------------------------------------------------------------------


@router.get("/daily-summary", response_model=DailySummaryResponse)
async def daily_summary(
    req: Request,
    user_id: Annotated[str, Depends(get_current_user)],
) -> DailySummaryResponse:
    reminder_svc = ReminderService(req.app.state.db)
    schedule_svc = ScheduleService(req.app.state.db)
    reminders = reminder_svc.list(user_id)
    schedule = schedule_svc.list(user_id)
    summary = f"You have {len(reminders)} reminder(s) and {len(schedule)} schedule item(s)."

    return DailySummaryResponse(summary=summary)


# ---------------------------------------------------------------------------
# Server-side tool execution
# ---------------------------------------------------------------------------


async def _execute_server_tool(
    tool_call: dict,
    user_id: str,
    req: Request,
) -> str | None:
    """Execute a backend-side tool and return a voice-friendly result string."""
    name = tool_call["name"]
    args = tool_call.get("arguments", {})
    db = req.app.state.db

    try:
        if name == "get_current_time":
            from datetime import datetime

            return f"The current time is {datetime.now(UTC).strftime('%I:%M %p UTC')}."

        elif name == "get_current_date":
            from datetime import datetime

            return f"Today is {datetime.now(UTC).strftime('%A, %B %d, %Y')}."

        elif name == "save_note":
            svc = NoteService(db)
            svc.save(user_id, title=args["title"], content=args["content"])
            return f"Note '{args['title']}' has been saved."

        elif name == "list_notes":
            svc = NoteService(db)
            notes = svc.list(user_id)
            if not notes:
                return "You have no saved notes."
            titles = ", ".join(n["title"] for n in notes[:5])
            return f"Your notes: {titles}."

        elif name == "read_note":
            svc = NoteService(db)
            note = svc.read(user_id, args["note_id"])
            if not note:
                return "I couldn't find that note."
            return f"{note['title']}: {note['content']}"

        elif name == "delete_note":
            svc = NoteService(db)
            ok = svc.delete(user_id, args["note_id"])
            return "Note deleted." if ok else "I couldn't find that note."

        elif name == "create_reminder":
            svc = ReminderService(db)
            svc.create(
                user_id,
                title=args["title"],
                scheduled_at=args["scheduled_at"],
                note=args.get("note"),
                timezone_str=args.get("timezone", "UTC"),
            )
            return f"Reminder '{args['title']}' set for {args['scheduled_at']}."

        elif name == "list_reminders":
            svc = ReminderService(db)
            items = svc.list(user_id)
            if not items:
                return "You have no pending reminders."
            titles = ", ".join(r["title"] for r in items[:5])
            return f"Your reminders: {titles}."

        elif name == "complete_reminder":
            svc = ReminderService(db)
            ok = svc.complete(user_id, args["reminder_id"])
            return "Reminder marked as done." if ok else "Reminder not found."

        elif name == "delete_reminder":
            svc = ReminderService(db)
            ok = svc.delete(user_id, args["reminder_id"])
            return "Reminder deleted." if ok else "Reminder not found."

        elif name == "create_schedule_entry":
            svc = ScheduleService(db)
            svc.create(
                user_id,
                title=args["title"],
                starts_at=args["starts_at"],
                ends_at=args.get("ends_at"),
                description=args.get("description"),
                timezone_str=args.get("timezone", "UTC"),
            )
            return f"Schedule entry '{args['title']}' created."

        elif name == "list_schedule":
            svc = ScheduleService(db)
            items = svc.list(user_id)
            if not items:
                return "Your schedule is empty."
            titles = ", ".join(e["title"] for e in items[:5])
            return f"Upcoming schedule: {titles}."

        elif name == "delete_schedule_entry":
            svc = ScheduleService(db)
            ok = svc.delete(user_id, args["entry_id"])
            return "Schedule entry deleted." if ok else "Entry not found."

        elif name == "save_preference":
            svc = PreferenceService(db)
            svc.save(user_id, key=args["key"], value=args["value"])
            return f"Preference '{args['key']}' saved."

        elif name == "recall_preference":
            svc = PreferenceService(db)
            value = svc.get(user_id, key=args["key"])
            return (
                f"Your preference for '{args['key']}' is '{value}'."
                if value
                else f"I don't have a preference saved for '{args['key']}'."
            )

        elif name == "provide_daily_summary":
            from datetime import datetime

            reminder_svc = ReminderService(db)
            schedule_svc = ScheduleService(db)
            reminders = reminder_svc.list(user_id)
            schedule = schedule_svc.list(user_id)
            return (
                f"You have {len(reminders)} pending reminder(s) "
                f"and {len(schedule)} schedule item(s)."
            )

        else:
            return None

    except Exception as error:  # noqa: BLE001 - isolate dynamic tool failures
        logger.error("Server tool execution failed: %s", type(error).__name__)
        return "I couldn't complete that action."
