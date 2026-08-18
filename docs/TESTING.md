# Testing

Last reviewed: 2026-08-14

## Strategy

Automate pure parsing, provider selection, tool validation, state orchestration,
settings, routes, semantics, retention, and error behavior. Use real local
Ollama/backend checks for optional service integration. Do not infer microphone,
TalkBack, TTS/haptic, camera, Pi hardware, thermal, or hostile-network behavior
from mocks or desktop tests.

Test prefixes remain `UT` (unit/controller), `WT` (widget/accessibility), `IT`
(Android integration), and `MT` (manual physical acceptance).

## Current Automated Coverage

```text
mobile_app/test/
  accessibility/ app/ core/ domain/ features/
  features/assistant/      # active routes, UI, controllers, secure credentials
  features/wearable/
laptop_backend/tests/
  unit/                    # providers, fallback, keys, commands, tools, auth
  integration/             # health, pairing, text/audio/history boundaries
raspberry_pi/tests/
```

Assistant coverage includes bundled speech/native-channel truthfulness, focused
“Hey Vision AI” grammar/matching, `[unk]` cleanup and false-wake rejection, no remote fallback, unpaired
spoken app-control routing, serialized Riverpod lifecycle,
secure credential migration/storage calls, sensitivity execution, responsive
2x text, deterministic commands, argument ranges/types, confirmations, audio
type/size/duration validation, text-only Gemini payloads, `store:false`, key
precedence, structured parsing, fallback, and default no-history persistence.

## Latest Exact Results

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed; 179 files, 0 changes |
| `flutter analyze` | Passed; no issues |
| `flutter test` | Passed; 202 tests, 1 skipped Pi cross-process test |
| Android `:app:testDebugUnitTest` | Passed; 5 wake/parser-contract tests |
| backend `.venv/bin/ruff format .` | Passed; 34 files unchanged |
| backend `.venv/bin/ruff check .` | Passed; all checks passed |
| backend `.venv/bin/pytest -q` | Passed; 49 tests, 29 upstream warnings |
| live Ollama generation | Passed; `llama3.2:3b` returned valid structured content |
| live Whisper transcription | Passed; `base` transcribed generated audio as `reduce sensitivity.` |
| live backend API | Passed; startup, health, pair, authenticated query, sensitivity tool |
| `uv run --extra test ...` in Pi | Failed before tests: PyPI DNS could not resolve a Ruff wheel |
| release Flutter build | Passed; 97,185,174-byte ARM64 artifact |
| `zipalign`/`apksigner`/installed package metadata | Passed; v2 signed, min 24, target 36, `1.3.3`/`2011` |
| initial `adb devices -l`; `adb mdns services` | No device initially; later wireless service advertised but TLS pairing was incomplete |

Subsequent physical result: TECNO BG6 connected by USB, ARM64 Android 13/API 33.
`adb install -r` updated the app to `1.3.3` successfully while preserving data.
The foreground app owns an active, unsilenced 16 kHz local recognizer session.
The no-response diagnosis found and fixed Vosk n-best `alternatives[]` versus
top-level `text` parsing. A typed offline capability query physically reached
Speaking and produced Google TTS speech playback. The subsequent wake retest
reached notification shade and lock/sleep, where lifecycle policy correctly
stopped the microphone; repeat it unlocked.
Two direct cold launches passed in 709 ms and 591 ms. Real Mobile Mode showed a
live preview, one detection and one active alert; camera connect/disconnect and
an empty final active-client list were verified. No app-scoped fatal exception,
ANR, or Flutter crash was found. Idle startup measured about 97 MB PSS; the five-
frame graphics sample is too small for a performance claim.

Release size is 97,185,174 bytes and SHA-256 is
`9430d92b35dca391b24b29521a30e1c294c0578498fa3619869827185713c8ae`.
No live Gemini success is claimed because no Gemini key was configured. Mock
transport tests verify the contract without using a secret or network.

## Required Phone Assistant Matrix

| Manual ID | Check | Pass criterion |
|---|---|---|
| `MT-ASST-PERM-001` | deny/grant/permanent deny/revoke microphone | truthful states, Open Settings, no fake recording |
| `MT-ASST-WAKE-001` | “Hey Vision AI”, then a separate command | spoken acknowledgement/result, full-graph bounded timeout, ready again, no false wake |
| `MT-ASST-AUDIO-001` | tap and hold/release on-device recognition | real transcript, cancel/background cleanup, no laptop/backend request |
| `MT-ASST-CMD-001` | sensitivity/settings/Mobile/Pi commands | real observed state changes, truthful errors |
| `MT-ASST-CONF-001` | sensitive action confirmation | spoken confirm/cancel and buttons work; never executes early |
| `MT-ASST-OFFLINE-001` | WAN/backend-off app-control session | on-device recognition, deterministic command, and TTS work on phone |
| `MT-ASST-OLLAMA-001` | WAN-off optional conversation | recognized text, Ollama, and TTS work on trusted LAN |
| `MT-ASST-GEMINI-001` | owner key success then forced outage | truthful provider; outage falls to Ollama |
| `MT-ASST-NET-001` | laptop/Wi-Fi interruption | typed recovery, no hang, temp audio deleted |
| `MT-ASST-ACC-001` | TalkBack and 2x font/display | logical focus/live state; no clipped confirmation |
| `MT-ASST-LIFE-001` | 20 wake/command/process/background cycles | no crash, duplicate session, retained mic/TTS; record battery/thermal |

## Existing Physical Product Matrix

Camera permission; real portrait/landscape boxes; representative detections;
audio/vibration/both; airplane-mode Mobile session; 20 camera lifecycle cycles;
phone mean/p95 inference, memory, battery and thermal behavior; complete
TalkBack review; real Pi NCNN/model/camera/audio/discovery/pair/reconnect/reboot/
IP-change/WAN-off behavior; and two OV5647 sessions all remain required.

## Privacy Checks

Never log/store frames, image bytes, audio content, API keys, bearer tokens,
Wi-Fi secrets, or personal identifiers. App-command audio stays inside the
phone-local bundled/dedicated recognizer and is not uploaded by the app.
Gemini may receive unmatched conversation text only after disclosure. Explicit notes/reminders are local
deliberate writes; general conversation retention stays off by default.
