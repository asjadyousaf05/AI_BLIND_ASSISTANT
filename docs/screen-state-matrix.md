# Screen State Matrix

Last reviewed: 2026-08-06

| Screen | Route | Implemented states | Current status |
|---|---|---|---|
| Startup | `/startup` | identity, offline/privacy copy, Continue | Implemented and tested |
| Camera Permission | `/permissions/camera` | rationale, unknown, granted, denied, permanently denied, Open Settings | Implemented; physical system-dialog checks pending |
| Mode Selection | `/modes` | Mobile selected, Pi selected/deferred | Implemented and tested |
| Home | `/home` | Mobile ready, inactive/active summary, navigation | Implemented and tested |
| Mobile Assistance | `/mobile-assistance` | idle, permission required/denied/permanent, loading camera, loading model, ready, detecting, paused, stopping, camera/model/inference/feedback error | Implemented; emulator Detecting/lifecycle passed, physical acceptance pending |
| Raspberry Pi | `/raspberry-pi` | disconnected/deferred, disabled connect/scan, switch to Mobile | UI shell only; runtime deferred |
| Pi Connection Error | `/raspberry-pi/error` | explicit local error/deferred recovery | UI shell only; runtime deferred |
| Settings | `/settings` | loaded local values, audio/vibration/both, low/medium/high, saved validation | Implemented and tested |
| Help | `/help` | multiple guide steps and finish | Implemented and tested |
| About/Safety | `/about-safety` | identity, offline/privacy, accessibility, safety limits | Implemented and tested |

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
- Pi controls remain unavailable until a separately authorized module.

