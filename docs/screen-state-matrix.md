# Screen State Matrix

Last reviewed: 2026-08-14

| Screen | Route | Implemented states | Current status |
|---|---|---|---|
| Startup | `/startup` | identity, offline/privacy copy, Continue | Implemented and tested |
| Camera Permission | `/permissions/camera` | rationale, unknown, granted, denied, permanently denied, Open Settings | Implemented; physical system-dialog checks pending |
| Mode Selection | `/modes` | Mobile selected, Pi selected | Implemented and tested |
| Home | `/home` | Mobile ready, inactive/active summary, start/stop, assistant/navigation | Implemented and tested |
| Mobile Assistance | `/mobile-assistance` | idle, permission required/denied/permanent, loading camera, loading model, ready, detecting, paused, stopping, camera/model/inference/feedback error | Implemented; emulator Detecting/lifecycle passed, physical acceptance pending |
| Raspberry Pi | `/raspberry-pi` | unconfigured, discovering, found, pairing, paired, connecting, authenticating, connected, starting, running, pausing/paused, stopping, reconnecting, unavailable, incompatible, authentication/error, telemetry/settings | Implemented and simulator-tested; physical phone/Pi acceptance pending |
| Pi Connection Error | `/raspberry-pi/error` | explicit typed local error, retry/recovery, switch to Mobile | Implemented and tested; physical recovery pending |
| Settings | `/settings` | loaded local values, audio/vibration/both, low/medium/high, saved validation | Implemented and tested |
| Help | `/help` | multiple guide steps and finish | Implemented and tested |
| About/Safety | `/about-safety` | identity, offline/privacy, accessibility, safety limits | Implemented and tested |
| Assistant | `/assistant` | unpaired with offline voice/typed controls, requesting permission, checking offline speech, listening, processing, awaiting confirmation, executing, speaking, laptop/provider/auth/error | Implemented and automated; physical voice/TalkBack open |
| Assistant Connection | `/assistant/connection` | unpaired, private-host validation, pairing, paired, expired/invalid/unreachable | Implemented and automated; physical LAN pairing open |
| Assistant Settings | `/assistant/settings` | privacy/provider disclosure, connection, local history, disconnect/clear | Implemented and automated; physical TalkBack open |

## Mobile Assistance Visible Data

Detecting shows an aspect-correct camera preview, corrected normalized bounding
boxes/labels, detection count, active alert count, feedback mode, current alert,
and Stop. When no useful stable object exists, detection/alert counts remain
zero rather than fabricating a result.

## Recovery Rules

- Permission permanent denial exposes Open Settings.
- Camera/model/inference failure does not start or continue assistance.
- Partial feedback failure exposes a warning while the remaining selected
  channel continues; total failure becomes a feedback error.
- Backgrounding ends in Paused and requires explicit Resume.
- Stop/error cleanup releases camera, inference, TTS, and vibration.
- Pi errors preserve Mobile independence; retry is bounded, credentials can be
  forgotten/revoked, and phone transport loss does not stop Pi-owned assistance.
- Assistant on-device recognition cancels on route/lifecycle exit and discards
  its in-memory transcript. Unknown or invalid tools never execute.
- Typed app controls route and return deterministic results on-phone without a
  credential, backend health check, internet, Gemini, or Ollama.
- Sensitive assistant actions remain in Awaiting Confirmation until explicit
  Confirm or Cancel. Provider loss falls back to Ollama or reports unavailable.
