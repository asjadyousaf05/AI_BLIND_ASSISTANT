# Testing

## Project/GPT guide document verification — 2026-10-22

35 sequential main sections, 32 viva questions, balanced code fences and valid
Word ZIP/XML pass checks. Native Word export has 12 actual tables and semantic
headings; all body word tokens match the Markdown in order. macOS textutil reads
the final Word file successfully. Both actual phone model hashes and 80/601 label
counts match metadata. Source/Stitch preservation and whitespace results are in
[the document report](GPT_GUIDE_VERIFICATION_2026-10-22.md). No app/backend/Pi test
suite or Android build rerun; their guide counts are explicitly dated history.

## Module 76: Actual Pi restore and Pixel pairing — 2026-10-22

`raspberry_pi/.venv/bin/python -m pytest -o addopts='' raspberry_pi/tests -q --disable-warnings`
exits 0: **38 passed in 3.57 s**. `laptop_backend/.venv/bin/ruff check raspberry_pi/src raspberry_pi/tests`
and `sh -n raspberry_pi/scripts/install.sh raspberry_pi/scripts/hotspot_network_dispatcher.sh raspberry_pi/scripts/deploy.sh`
exit 0. All three model SHA-256 values and 19 deployed Python module hashes match.
Real OV5647/NCNN [605,2100]/601-class warm-up, enabled/running service, zero
restarts, growing processed-frame count, direct Pixel TCP client and actual app
enrollment/auth/settings/Running/Camera Active/Model Ready are verified.

No app/Pi source changes, new tests or Android rebuild; prior Module 75 artifact
evidence remains historical. Actual power remains 0x50005/~600 MHz. UI test-audio
activation is not acoustic acceptance; the owner separately confirms test audio
and real object announcements. Broader accuracy/TalkBack and corrected-power
performance remain open. [Exact commands and limitations](PIXEL_PI_RESTORE_2026-10-22.md).

Module 75 physical follow-up: owner confirms repeated commands and the ready cue
both work on installed Pixel 1.4.18. This bounded check does not close broader
accent/noise/TalkBack acceptance.

## Module 75: Vision AI listening reliability — 2026-10-21

673 full Flutter cases pass with the real local Python Pi simulator, no failures
or skips; 25 native app cases pass with zero failures/errors/skips. Analysis is
clean and formatting checks 10 Dart files with zero changes. New coverage includes
speaker-echo restoration, cue ordering/failure, transient and persistent resume
failure, shared recovery, background/stop invalidation, concurrent starts,
duplicate/empty callbacks, explicit restart, full Activity lifecycle restart,
native resume acknowledgement, negation/unknown-word rejection, whole-word repair
and bounded cue cleanup. Do not delete/skip tests or infer physical ASR quality.
[Exact commands, intermediate corrections and build/device evidence](VISION_AI_RELIABILITY_2026-10-21.md).

## Module 74 — 2026-10-21

[Verification](SMART_AI_FRESH_PHONE_2026-10-21.md): **652 Flutter cases pass**
(6 new, real Python Pi simulator, 19 s), **89 focused pass**, analysis clean
(2.8 s), nine changed Dart files formatted/zero changes (0.06 s). ARM64 1.4.17/
code 4057 debug build passes (9.8 s). Release/install evidence and hashes are in
the report. Native source unchanged: prior 22 native passes are historical,
not a rerun. No provider test, recording or key transfer.

Coverage verifies fresh circle/disabled semantics, no enabled-cloud claim,
start/hold/send gate and no recorder/client construction before opt-in, local
help/cue, setup callback, narrow/2x text, saved Gemini/paired preservation and
setup-save/removal round trips preserving unsent drafts. Existing legacy assertions
enter that mode explicitly; router fixtures inject local storage/audio instead of
leaving real platform calls pending. Initial failures and exact fixes are recorded.

Final 1.4.17/code 4057 debug/release builds pass (9.8/24.2 s). Matching-signer/
alignment/non-debuggable/package/delivery checks pass; installed Pixel bytes match
and its first-install time is retained. Cold MainActivity launch succeeds in
217 ms / 220 ms wait; later lock does not invalidate that recorded launch. The
owner confirms the large circle and Set up Smart AI button now appear. UI mismatch
resolved; next action is personal Groq key/consent setup on Pixel. No paid test.

## Module 73 — 2026-10-21

[Exact evidence](VISION_AI_COMMANDS_2026-10-21.md): final **646 Flutter tests**
pass (31 new, actual Python Pi simulator), clean analysis (3.8 s), 14-file format
check/zero changes. Final native app rerun: **22 tests**, 0 failures/errors/skips,
BUILD SUCCESSFUL in 2 s. ARM64 1.4.16 debug/release builds pass (9.9/924.1 s).
Matching-installed signature, alignment, metadata, packaged command changes and
delivery bytes pass. The report records all initial test/style findings and fixes,
installation and physical limits. No paid/provider probe or raw transcript log.

New coverage verifies progress ordering/no intermediate mic resume, duplicate
suppression, actual Pi/mobile/wearable outcomes, screen routing and restored
reader context, polite navigation in every context and native focused grammars,
Listen wake/echo protection, manual context gates, direct Smart AI idle/paused
controls, capture handover/preference restoration and speech-release ownership.


### Latest deployment target: Pixel 9 Pro — 2026-10-21

Owner redirected installation to the connected Pixel 9 Pro. Same verified
1.4.16/code 4056 artifact installed successfully as a fresh app; pulled installed
SHA-256 matches delivery, DEBUGGABLE absent. MainActivity is later foreground and
the process is alive with zero current-process fatal markers. Initial launch
ended at permission UI (362/364 ms), not measured app-only cold latency. User
granted microphone access; camera remains ungranted. Google TTS service exists;
physical speech/haptic/voice acceptance is still pending. No source/build/provider
request, phone-setting change or credential transfer. Set up personal Smart AI
keys/consent and Pi pairing separately on this phone. [Exact results](VISION_AI_COMMANDS_2026-10-21.md#owner-directed-pixel-9-pro-installation--2026-10-21).

## Module 72 — 2026-10-21

[Verification](SMART_AI_READY_CUE_2026-10-21.md): 615 Flutter cases pass including
the real Python simulator (9 new from 606), analysis clean (3.0 s), nine scoped
Dart files formatted/zero changes. Final native app unit task succeeds in 3 s:
21 tests, 0 failures/errors/skips (4 new from 17). Initial native task was 27 s;
final rerun covers the foreground lifecycle guard. This is not an aggregate
plugin/lint pass. ARM64 1.4.15/code 4055 debug/release builds pass in 19.3/31.8 s. Signature
matches the last installed phone signer, 16 KiB alignment/non-debuggable metadata
and delivery bytes pass; no installation requested. Exact artifact hashes are
in the verification report.

New coverage verifies cue after native recording, visible cue failure without
blocking capture, stop on cancel/submit/background, no recording/provider on test,
correct partial fallback messages and payload-free local bridge. Native tests
exercise independent output failures, late cleanup vs replacement, bounded effect
parameters and cancellation invalidating old cleanup. First full run 614 pass/
1 new test failure exposed a fake recorder ownership race during lifecycle and
teardown; it now clears ownership before async deletion as production already
does. All assertions remain and final suite passes. User chose later device
acceptance; no motor/speaker/installation claim or provider diagnostic call.

## Module 71 — 2026-10-20

[Exact evidence](SMART_AI_CIRCLE_2026-10-20.md): **591 Flutter tests pass**,
20 more than the previous 571, including the real Python simulator. Analysis
has no issues (2.5 s); scoped 17-file format check has zero changes. ARM64
1.4.13 debug/release builds pass in 14.5/23.7 s. Candidate signature matches the
installed predecessor, 16 KiB alignment passes and the in-place installation
succeeds. Pulled installed bytes match; code 4053, DEBUGGABLE absent,
first-install time preserved. Cold launch Status ok/COLD, TotalTime 1114 ms,
WaitTime 1186 ms. No native edit: prior 13 native passes are historical evidence,
not a rerun in this module. Existing plugin Kotlin migration warnings remain.

New cases cover latest English after Urdu history and Urdu after English history,
exact base prompt retention, hold cue/release exactly once, early-release setup
cleanup, pointer cancellation, capped hold ownership/duplicate prevention,
local pause/resume without new API, interruption before capture, exact goodbye
variants vs incidental mentions, recorded goodbye clip cleanup/no LLM, release
before navigation, last-word replay on resume, stop while paused, one-second
recognizer timing and semantic tap without a hold. Existing narrow/2× UI passes.
Focused runs 84 and 22 passed before the final full suite. Initial recognizer
compile/style/deprecation/import findings were corrected without dropping tests.
Physical new-circle/language/haptic/pause/goodbye check is requested; no provider
test call was made by the agent. Vision/native/backend/Pi/Stitch are preserved.

## Module 70 — 2026-10-19/20

[Exact evidence](SMART_AI_CLOUD_AUDIO_2026-10-19.md): **571 Flutter cases pass**
(73 new, real Python simulator), analysis clean (2.5 s), 25-file format check/
zero changes. After final style fixes, 15 localized-adapter/widget tests pass.
1.4.12 ARM64 debug/release builds pass in **9.2/22.9 s**. Earlier native app task
passes **13 tests**, zero failures/errors/skips, after the only native cache
lookup edit (unchanged since). Matching-signer **1.4.12/code 4052** is installed;
bytes/non-debuggable flags/first-install time verified. Cold launch Status ok,
TotalTime 1030 ms, WaitTime 1068 ms. No aggregate plugin/lint status is promoted.

Coverage includes bounded sequential STT/LLM/TTS, cleanup/cancel/native-start/
audio handover, late results/timeouts, exact prompt/model/destinations, Groq-only
same-key isolation, excluded reasoning, no redirects/retries/tools, safe HTTP
classification and bounded client-policy parsing, legacy/unknown provider
storage, saved-key reuse/fresh consent, narrow/2× UI, offline Urdu/English voice
selection, uninstalled/missing voice data, cancellation during selection/speech,
restore-English failure paths and local replay without provider/control calls.

Physical capture/cancel and encrypted key/provider save pass; Groq application
HTTP-stack metadata returns 200 with both models. Owner confirms Urdu recognized
and Urdu text answers, but speech-language mismatch on 1.4.11. Urdu pack is
installed; owner confirms repaired 1.4.12 Urdu speech and local replay both work.
Local capture/cancel, background/resume and settings reentry pass without uploads;
current process alive with zero app fatal markers. Full noise/TalkBack/latency
and local wake acoustic matrices remain separate. Prior
AgentRouter denial/timeouts/misleading size advice and corrected initial 1.4.8
microphone failure remain in the record. Tests use synthetic keys/local HTTP.

## Module 69 — 2026-10-19

[Exact command, artifact and physical evidence](HOTSPOT_AND_GEMINI_VERIFICATION_2026-10-19.md):
498 Flutter (real Pi simulator enabled), 128 backend, 38 Pi and 13 native app
tests pass; analysis/Ruff/formatting and debug/release builds pass. Physical
TECNO BG6 hotspot discovery/enrollment/authentication/settings/Running, actual
OV5647/NCNN and phone audio test pass. The owner confirms clear sound; the final
TTS-budget repair removes the false warning. Installed bytes and signer match
the data-preserving release-mode candidate. Current Pi under-voltage/throttling
blocks sustained-performance acceptance, including after changing to the owner's
5 V/2 A adapter. Owner confirms real object speech but still rejects speed after
tuning. Eight-frame camera comparisons and aggregate live timings are in the
report; no accuracy gain is claimed. Five current/history power vectors and
three real cross-stack cases pass; final disclosure-only Flutter follow-up has
118 assistant passes/clean analysis and rebuilt/reinstalled debug/release outputs.
Actual phone/laptop hotspot pairing and a typed Ollama reply pass. Full recovery/
offline/TalkBack/fallback and live personal Gemini remain physical gates.

## Module 67 reader interruption — 2026-10-15

[Exact commands/results and physical matrix](READER_VOICE_VERIFICATION_2026-10-15.md).
459 Flutter tests and 13 native app tests pass, with clean analysis/formatting
and debug/release builds. Tests hold actual reader speech open while injecting
native proposals for stop/pause/repeat/restart/line/spelling/speed controls;
printed commands and wake phrases do not execute. Late claims after navigation
or suspension and stale TTS cancel/completion/progress are rejected.
Software-injected transcripts are not acoustic recognition measurements.

On the target phone, test these controls while the loudspeaker is reading, then
read a synthetic page containing the same command phrases without speaking.
Repeat across usual volumes/noise, spelling, different speakers, lifecycle,
TalkBack and microphone revocation before closing ISSUE-071.

## Module 66 voice and Smart AI verification — 2026-10-15

Exact commands/results: [VOICE_FIXES_2026-10-15.md](VOICE_FIXES_2026-10-15.md).
404 Flutter, 108 backend and 9 fresh native app tests pass; analysis, Ruff,
formatting and ARM64 debug/release builds pass. The release is installed on the
emulator with matching checksum, non-debuggable flags and successful Home →
Smart AI navigation. Opening the unpaired emulator screen shows pairing guidance;
saved-pairing connection success/failure/timeout paths are automated evidence.

Runtime follow-up on the same date: existing release app launch returned
Status ok; `GET http://127.0.0.1:8765/health` reported ok/protocol 1,
Ollama available, model `llama3.2:3b`, Gemini not configured. Pairing used
`PYTHONPATH=src .venv/bin/python scripts/create_pairing_code.py` from
`laptop_backend/` with its output held only in memory, then the emulator's
Connection form at the existing `10.0.2.2:8765` preset. Smart AI reported
reachable on return. A synthetic typed “Reply with the single word ready.”
request received “ready”; no request/error remained visible. No document was
sent, no voice audibility claim is made, and no test suite/build was rerun for
this launch-only follow-up. The release app and local services remain running.

Later owner-authorized phone installation: current-dialog `adb pair` and
`adb connect 192.168.10.36:36063` succeeded after stale pairing-port failures.
TECNO LE6 reports ARM64 and API 30, with no prior installed package.
`adb -s 192.168.10.36:36063 install --no-incremental -r <release-apk>` exited 0,
Success. Package queries show 1.4.3/code 4043 and no DEBUGGABLE flag; phone
`sha256sum <installed-base.apk>` matches the verified release. Direct
`am start -W -n com.example.ai_blind_assistant/.MainActivity` exited 0,
Status ok/COLD, TotalTime 5599 ms/WaitTime 5621 ms. Process alive, app resumed,
welcome Continue visible, no permission dialog, and zero current-process
crash-buffer fatal markers. No permission was granted automatically, no
conversation/document was submitted, and physical feature acceptance remains
open. No source/build/test-suite change was needed for this installation.

Physical acceptance to run when authorized:

1. Start a Scanner reading session. Say “scan again”, “restart scanner” and
   polite variants. Each must stop old reading and return to live framing with
   the old page cleared. Wait and reposition: no photo/OCR may occur. Say “scan
   document” or tap Scan when ready; only then capture/read the new page. Repeated
   pending requests must not overlap captures. Verify temporary-photo cleanup
   and camera recovery after backgrounding. This follows the owner's later
   framing correction, superseding Module 66's original immediate capture.
2. Say “restart reading”: it must read the first unit of the existing page.
   Touch Scan Another Document must still return to framing.
3. With an active offline command session, say buy/by/bye, ordinary sentences
   containing those words and sentences quoting goodbye. The session must
   continue. Complete “goodbye”/“stop listening” must restore wake-only mode.
4. Open Smart AI with saved laptop pairing: observe Connecting and Reachable,
   or truthful unavailable/version/auth guidance. Local commands stay usable.
   Stop the backend, retry, restore it and reopen; no old question is replayed.
5. Confirm an OCR draft remains editable/unsent on entry and connection retry.
   First-time laptop pairing remains explicit. “Exit Smart AI” returns to the
   offline command session; verify noisy/echo/TalkBack cases on real hardware.

## Module 65 hotspot and phone-output verification — 2026-10-09

Exact commands, outcomes and failure reproduction are recorded in
[HOTSPOT_VERIFICATION_2026-10-09.md](HOTSPOT_VERIFICATION_2026-10-09.md).
Final software results: 393 Flutter passes (0 skips), 33 Pi passes, clean Dart
analysis/Ruff, dedicated Pi runtime `pip check` clean. The cross-stack test uses
`AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python` and
`PYTHONPATH=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/src`.

Physical acceptance is **not run**. Only an emulator is attached, and
`rpi3-ml.local` does not resolve from this Mac. With the actual phone and Pi:

1. Deploy the matching Pi service, enable the owner's 2.4 GHz hotspot, and join
   the Pi once using the setup in PHONE_HOTSPOT.md. Disable cellular data.
2. Open Wearable and activate Test Phone Audio; record whether the phrase is
   audible at the intended media volume. Muted Audio Alerts must show the
   explicit note; the explicit test may still speak.
3. Connect & Start Detection. Record discovery/current private address,
   enrollment or saved-trust reuse, synchronized settings, camera/model state,
   and Running. Cancel during settings/start must remain reachable.
4. Present safe stationary objects. Record correct class/direction spoken by
   the **phone**, no duplicate Pi speech, bounded repetition and false results.
5. Pause/Stop: verify speech stops and late alerts do not restart it. Resume
   and test hotspot interruption, changed DHCP address, Pi restart and retry.
6. Disconnect/background: verify phone speech stops, existing Pi assistance
   continues with Pi-local fallback, and foreground reconnect restores the Pi's
   reported state. A rebooted idle Pi still requires Start Detection.
7. Repeat with TalkBack, 2× text, audio disabled, TTS unavailable, low media
   volume and a second phone rejected by exclusive enrollment.

Record observed device results before closing ISSUE-048/050. Simulator text
callbacks, emulator launch and passing tests do not prove audible target-phone
output or real scene detection quality.

Last reviewed: 2026-10-09

## Module 64 whole-project audit evidence

Verified on 2026-10-09: 376 Flutter tests (no skips), 88 backend tests,
16 Pi tests and 8 fresh native app tests pass. Dart analysis and Ruff are clean;
formatting, model checks, debug/release APKs and local Ollama/Whisper smoke pass.
Measured instrumented Dart line coverage is 61.36%; physical acceptance and
aggregate native/lint dependency blockers remain open.

Current exact automated results, coverage limits, model/APK inspection and
live local-provider smoke evidence are in
[PROJECT_AUDIT_2026-10-09.md](PROJECT_AUDIT_2026-10-09.md). New tests cover
rejected pairing, user/request/tool-bound server confirmation and replay,
malformed audio/history/model input, temporary-file cleanup, real data effects,
selected-endpoint HTTP/redirect/timeout boundaries and truthful device commands.
Both APK variants build. No physical device was attached; the manual matrices
below remain mandatory. Aggregate native plugin tests and Android lint have
explicit dependency blockers; these checks are not counted as passing.

## Module 63 Labeling Evidence

On 2026-10-03, 46 targeted accessibility/screen/route tests passed. Full
Flutter suite: 351 passed, one Pi simulator environment skip, no failures.
Changed-file analysis is clean. Full analysis retains the two pre-existing
assistant-controller unused imports. Android debug APK built successfully.
No Android device was attached; physical TalkBack acceptance is unverified.

`test/accessibility/control_labels_test.dart` verifies exact action names,
enabled/disabled and selected state, semantic activation, native navigation,
and cooldown seconds plus increase/decrease actions. Scanner tests verify 14
reader controls and changing Start/Pause/Resume names; assistant tests verify
voice activation names, the text alternative and native Send tooltip.

Manual next action: enable TalkBack and use swipe gestures to visit Home,
Modes, Settings, Mobile Mode, Wearable, Scanner and Vision AI. With the blind
user, verify each control announces one clear name, its available state, and
its purpose; double-tap must execute it once. Confirm slider adjustments speak
seconds, selected settings announce state, and Pause/Resume/Stop names match
the reader. Record exact phone/Android/TalkBack versions and observations
before closing ISSUE-008.

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

## Historical Module 57 Results

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
