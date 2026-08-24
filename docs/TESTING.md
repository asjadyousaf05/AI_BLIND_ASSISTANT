# Testing

Last reviewed: 2026-08-20

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
| `dart format lib test integration_test test_ssh.dart` | Passed; 226 files, 0 changed after formatting |
| `flutter --no-version-check analyze --no-pub` | Passed; no issues |
| `PYTHONPATH=../raspberry_pi/src AIBA_PI_PYTHON=../laptop_backend/.venv/bin/python flutter --no-version-check test --no-pub` | Passed; 319 tests, 0 failed, including code-free cross-stack simulator process |
| Android `:app:testDebugUnitTest` | `BUILD SUCCESSFUL` under Java 17 |
| Pi Ruff through existing isolated Python environment | Passed; all checks passed |
| Pi pytest through existing isolated Python environment | Passed; 15 tests, 46 upstream Python 3.14 warnings |
| backend `.venv/bin/ruff format .` | Passed; 34 files unchanged |
| backend `.venv/bin/ruff check .` | Passed; all checks passed |
| backend `.venv/bin/pytest -q` | Passed; 49 tests, 29 upstream warnings |
| live Ollama generation | Passed; `llama3.2:3b` returned valid structured content |
| live Whisper transcription | Passed; `base` transcribed generated audio as `reduce sensitivity.` |
| live backend API | Passed; startup, health, pair, authenticated query, sensitivity tool |
| dedicated fresh Pi `.venv` | Still lacks Ruff/pytest after the earlier PyPI DNS failure; current Pi suite ran through the existing isolated laptop environment |
| release Flutter build | Passed; ARM64 125,769,244 bytes |
| `adb install -r` / installed package metadata | Passed; signed `1.4.2`, ABI-adjusted code `4042`, min 24, target 36 |
| Android launch/fatal-marker smoke | Launch request passed; process alive/focused behind sleeping/locked shade; no app-scoped fatal marker |
| latest `ping`/TCP probes for `10.141.17.148` | Blocked: phone lost 2/2 packets; Mac TCP 22 and 8765 timed out |

Physical history: TECNO BG6 connected by USB, ARM64 Android 13/API 33. Module 57
`adb install -r` updated the app to `1.4.2` / split code `4042` successfully
while preserving data. The screen was asleep/locked, so no new cold-launch
timing is claimed; the app process remained alive/focused and showed no
app-scoped fatal marker. Earlier Module 56 cold launch completed in 1,191 ms
with the process top resumed. Earlier acceptance established that the
foreground app owns an active, unsilenced 16 kHz local recognizer session.
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

Current installed release size is 125,769,244 bytes and SHA-256 is
`a4ab50e4ef27c73104eec96c11854dbb088a5e407ecf175eb87d8abbf6a8717c`.
No live Gemini success is claimed because no Gemini key was configured. Mock
transport tests verify the contract without using a secret or network.

## Required Phone Assistant Matrix

| Manual ID | Check | Pass criterion |
|---|---|---|
| `MT-ASST-PERM-001` | deny/grant/permanent deny/revoke microphone | truthful states, Open Settings, no fake recording |
| `MT-ASST-WAKE-001` | 20 each of “Hey Vision AI” and “Hi Vision AI”, then several commands without re-waking, followed by “goodbye” | one acknowledgement, every result, timeout keeps the contextual session active, goodbye restores wake-only mode, no false wake/action |
| `MT-ASST-NOISE-001` | quiet, fan, TV/music, nearby speech, and phone-speaker TTS | no activation without a complete branded phrase; record every miss/false wake/wrong action |
| `MT-ASST-SMART-001` | “Open Smart AI”, two follow-ups, local app control, then “bye” | same local Vosk input, text-only backend request, local controls retain priority, active offline command session restored |
| `MT-ASST-SCAN-001` | one wake, then scan, pause/start/stop/resume, previous/next/first/last/line 5, repeat/spell, speed/copy/camera/torch/rescan variants, then goodbye | every valid Scanner action reaches the matching visible controller without re-waking; requested audio starts and unrelated noise performs no action |
| `MT-ASST-AUDIO-001` | tap and hold/release on-device recognition | real transcript, cancel/background cleanup, no laptop/backend request |
| `MT-ASST-CMD-001` | sensitivity/settings/Mobile/Pi commands | real observed state changes, truthful errors |
| `MT-ASST-CONF-001` | sensitive action confirmation | spoken confirm/cancel and buttons work; never executes early |
| `MT-ASST-OFFLINE-001` | WAN/backend-off app-control session | on-device recognition, deterministic command, and TTS work on phone |
| `MT-ASST-OLLAMA-001` | WAN-off optional conversation | recognized text, Ollama, and TTS work on trusted LAN |
| `MT-ASST-GEMINI-001` | owner key success then forced outage | truthful provider; outage falls to Ollama |
| `MT-ASST-NET-001` | laptop/Wi-Fi interruption | typed recovery, no hang, temp audio deleted |
| `MT-ASST-ACC-001` | TalkBack and 2x font/display | logical focus/live state; no clipped confirmation |
| `MT-ASST-LIFE-001` | 20 wake/command/profile/background cycles with app-scoped logcat | no crash/native tombstone, duplicate session, or retained mic/TTS; record battery/thermal |

## Existing Physical Product Matrix

Camera permission; real portrait/landscape boxes; representative detections;
audio/vibration/both; airplane-mode Mobile session; 20 camera lifecycle cycles;
phone mean/p95 inference, memory, battery and thermal behavior; complete
TalkBack review; real Pi NCNN/model/camera/audio/discovery/enroll/reconnect/reboot/
IP-change/WAN-off behavior; and two OV5647 sessions all remain required.

## Privacy Checks

Never log/store frames, image bytes, audio content, API keys, bearer tokens,
Wi-Fi secrets, or personal identifiers. App-command audio stays inside the
phone-local bundled/dedicated recognizer and is not uploaded by the app.
Gemini may receive unmatched conversation text only after disclosure. Explicit notes/reminders are local
deliberate writes; general conversation retention stays off by default.
