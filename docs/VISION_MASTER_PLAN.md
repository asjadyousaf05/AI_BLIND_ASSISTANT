# Vision Master Plan

Last updated: 2026-08-18

## Project Goal

Make **every meaningful supported function** of the AI Blind Assistant mobile
application operable by voice, while retaining buttons, TalkBack, and accessible
touch controls as fallback interfaces. The application must be stable enough that
a blind person can confidently rely on it through voice alone.

## Architecture

### Single-Owner Principle

```
ONE microphone owner
ONE active ASR pipeline (Vosk, on-device)
ONE global voice kernel (VisionVoiceKernelV3)
ONE TTS coordinator (SpeechOutputService + FlutterTts)
ONE context manager (VoiceFeatureContext)
ONE intent resolver (IntelligentIntentResolver)
ONE command authorization layer (CommandAuthorizer)
ONE command executor (CommandExecutor)
```

### Voice Pipeline

```
USER SPEAKS NATURALLY
        ↓
OFFLINE ASR (Vosk)
        ↓
DETERMINISTIC NLU (IntelligentIntentResolver)
        ↓
CURRENT CONTEXT (VoiceFeatureContext)
        ↓
AUTHORIZATION (CommandAuthorizer)
        ↓
SESSION / STALE / DEDUP CHECKS
        ↓
EXACTLY ONE CANONICAL ACTION
        ↓
EXISTING DOMAIN CONTROLLER
        ↓
SHORT ACCESSIBLE FEEDBACK
```

### UI and Voice Share Business Logic

```
UI button  ─┐
             ├─→ SAME DOMAIN CONTROLLER
Voice     ─┘
```

No duplicate voice-specific feature implementations.

## Implementation Phases

| Phase | Description | Depends On |
|---|---|---|
| A | Audit + Git baseline + documentation files | — |
| B | Diagnostics only (no behavior change) | A |
| C | Single microphone / recognizer / TTS ownership | B |
| D | Session IDs + stale event rejection + dedup + TTL | C |
| E | NLU / semantic resolver / natural phrase handling | D |
| F | Confirmation / cancel flow | E |
| G | Mobile Detection voice integration | F |
| H | Scanner explicit scan request architecture | G |
| I | Scanner Reader single-controller ownership | H |
| J | Pause / Resume / Stop / Next / Previous / Repeat | I |
| K | Slow / Normal / Fast profiles | J |
| L | Scanner barge-in + TTS echo guard | K |
| M | Settings voice coverage | L |
| N | Raspberry Pi / Wearable coverage | M |
| O | Smart AI entry/control integration | N |
| P | Full app voice coverage audit | O |
| Q | Long-run physical torture testing | P |

## Non-Negotiable Rules

1. DO NOT modify YOLO/LiteRT weights, labels, input dimensions, preprocessing,
   confidence threshold, NMS, camera image format, frame throttling, model
   initialization, or inference threading unless evidence proves the detection
   subsystem itself is faulty.
2. Core application commands remain OFFLINE (Vosk). No cloud ASR for
   deterministic app control.
3. Every scan must come from an explicit user action (UI button, voice command,
   or accessibility action). No auto-scan from build, initState, provider
   rebuild, OCR completion, TTS completion, reader completion, pause, resume,
   stop, unknown command, voice timeout, or route restoration.
4. ONE authoritative reader instance for active document. UI and voice share it.
5. Every async callback must prove it belongs to current state (session ID,
   generation, context).
6. Normal commands execute from FINAL recognition only. Partials are diagnostic
   only.
7. Unknown speech without wake word: IGNORE SILENTLY.
8. No cloud inference, remote config, analytics, remote crash reporting, or
   remote fonts.
9. Never log raw microphone audio, camera frames, face data, or personal
   identifiers.

## Acceptance Tests Summary

See `VISION_TEST_MATRIX.md` for the complete list.

Key physical device tests:
- Home: battery, time, settings navigation, go home
- Mobile Detection: start/pause/resume/stop, scene query, back-during-detection
- Scanner: open-without-scan, scan-exactly-once, all reader buttons
- Reader: pause/resume preserves sentence, completion no auto-scan
- Self-echo: document text cannot control app
- Barge-in: Vision interrupts TTS, reader resumes correctly
- Confirmation: confirm/cancel with all synonym variations
- Long-run: 20+ screen cycles with no degradation

## Final Definition of Done

On physical Android device, ALL tests from Section 51-52 of the master prompt
pass. No stale commands, duplicate commands, ghost listeners, voice feedback
loops, repeated Invalid command, unexpected navigation, automatic scanner
captures, duplicate inference pipelines, duplicate reader controllers, TTS
self-command, or old callbacks changing new state.
