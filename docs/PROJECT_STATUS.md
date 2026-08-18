# Project Status

Last updated: 2026-08-18

## Overview

| Field | Status |
|---|---|
| Current work | Module 52 VisionVoiceKernelV3 physical device bug fixes |
| Overall state | Fixed TTS race conditions on reading resumption and resolved state drop during voice confirmation; 350 Flutter tests passed; 0 analyze issues; single-word 'Vision' wake phrase active |
| Mobile stack | Flutter 3.44.5 / Dart 3.12.2, Android min SDK 24, target 36 |
| Architecture | Feature-first layers, Riverpod DI/state, VisionVoiceKernelV3 voice layer, centralized named routes |
| Mobile assistance | CameraX, bundled YOLOv8n LiteRT, local TTS, bounded haptics |
| Wearable assistance | Authenticated local WebSocket v1, Pi NCNN/Picamera2/espeak-ng |
| Assistant controls | State-machine-driven VisionVoiceKernelV3, on-device Vosk, shared CommandExecutor |
| AI selection | Gemini first when configured; automatic local Ollama fallback |
| Active provider on this host | Ollama `llama3.2:3b`; Gemini key not configured |
| Release | `1.5.0`, split code `2050`, ARM64 |

## Implemented Capabilities

Mobile and Wearable modes remain independent, local assistive workflows. The
assistant can read status and control sensitivity, feedback, accessibility,
Mobile Mode, and Raspberry Pi Mode through real Riverpod controllers. Common
control phrases use deterministic parsing. Model-proposed actions must match a
strict allow-list and validated argument schema; sensitive actions wait for
explicit confirmation.

Typed app-control phrases are parsed before any credential or network check and
execute entirely on the phone. Foreground hands-free speech uses the Vosk model
bundled in the APK; manual voice prefers Android's dedicated on-device service
and falls back to Vosk. The idle listener uses a focused wake grammar and
switches to the full Vosk graph only after acknowledgement. Both use the same
deterministic phone route. Gemini and Ollama are reserved for unmatched general
conversation.

Voice recognition is bounded to the open foreground app and stops while locked
or backgrounded. App-command raw audio stays in phone-local recognizer memory
and is not stored or uploaded by the app.
Gemini receives only unmatched typed/transcribed conversation text and
conversation context after disclosure; it receives no camera frame or raw
audio. Without a Gemini key, optional conversation reasoning stays on the
laptop through Ollama. The core camera pipeline never depends on either AI
provider or the internet.

## Latest Evidence

- `flutter analyze`: no issues.
- `flutter test`: 350 passed tests.
- Fixed a TTS synchronization bug in the Document Scanner where overlapping speech calls caused the sentence loop to silently skip to the end on resumption.
- Added explicit confirmation intents (`ConfirmYes`/`ConfirmNo`) and decoupled the push-to-talk locking during `awaitingConfirmation`, allowing successful manual and wake-word voice cancellation.
- USB update installation passed on TECNO BG6, Android 13/API 33, ARM64.

## Open Acceptance and Limitations

| Gate | Required evidence |
|---|---|
| Android voice | real-speaker wake/command/spoken-confirm accuracy, permission denial/revocation, TTS/audio focus, repeated lifecycle, battery/thermal |
| Accessibility | TalkBack focus/order/live announcements, 2x text, confirmation controls |
| Providers | real Gemini key success and forced-failure Ollama fallback on the phone |
| App controls | sensitivity/settings/Mobile/Pi actions and truthful failure states |
| Mobile safety | camera boxes, TTS/haptics, airplane mode, lifecycle, thermal/performance |
| Raspberry Pi | deployment, discovery, pairing, NCNN/camera/audio, reconnect/reboot/IP change |
| Transport | trusted-LAN-only review; assistant HTTP is authenticated but not encrypted |

This is an assistive aid, not navigation and not a replacement for a cane,
guide dog, mobility training, human assistance, situational awareness, or user
judgment. Relative visual risk is not metric distance.

## Exact Next Action

Deploy to the connected physical device (TECNO BG6) and perform regression testing on:
1. Document Scanner: Pause reading, wait a few seconds, then say "resume". Verify it resumes without shifting to the end.
2. Settings Confirmation: Trigger a command that requires confirmation, then press the mic button or say "cancel". Verify it cleanly cancels.
