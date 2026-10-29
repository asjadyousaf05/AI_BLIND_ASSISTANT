# Requirements Traceability

## GitHub delivery evidence — 2026-10-29

NFR-MAINT-002 gains current distribution verification: 279 Dart files format
cleanly, clean analysis, 673 Flutter/128 backend/38 Pi passes, successful Android
unit-test task (25 cached cases), both ARM64 builds, signer/alignment/package/hash
checks. [Exact evidence and release links](GITHUB_DELIVERY_2026-10-29.md).
No functional or physical-acceptance requirement status is promoted.

## Project guide clarification — 2026-10-22

NFR-MAINT-002 documentation gains a checked self-contained project/GPT guide and
matching Word export. Current phone artifact hashes/label counts are rechecked;
no model training/accuracy, hardware acceptance or requirement status is promoted.
Unsupported completed fine-tuning wording is corrected (ISSUE-065). [Document
verification](GPT_GUIDE_VERIFICATION_2026-10-22.md).

## Module 76 operational evidence — 2026-10-22

FR-010/017/022 gain actual Pixel hotspot discovery/enrollment/authentication,
manual session control, settings sync and truthful Running/Camera Active/Model
Ready evidence after the owner reflashes the Pi. FR-008 gains owner-confirmed
audible test and actual object announcements on Pixel; FR-011 gains restored
startup but does not gain the full
induced-failure/reboot matrix. NFR-OFFLINE-001 retains phone/Pi-local inference
without a cloud dependency; WAN-disabled acceptance is not claimed. NFR-SEC-002/004
retain the approved private-hotspot/Keystore/protocol boundary with fresh local
trust after the reported reflash, not console-verified SSH identity or TLS.
NFR-MAINT-002 gains 38 passing Pi tests/3.57 s, clean Ruff/syntax, installed
source/model hashes and the [physical deployment report](PIXEL_PI_RESTORE_2026-10-22.md).
Active undervoltage/throttling and broad physical accessibility/accuracy gates
remain open; no provider degradation, new architecture or UI completion claimed.

Module 75 physical follow-up: owner confirms repeated commands and the ready cue
both work on installed Pixel 1.4.18. This bounded check does not close broader
accent/noise/TalkBack acceptance.

## Module 75 — Vision AI listening reliability (2026-10-21)

FR-013/014/015/021/022; NFR-ACC-001/002, NFR-OFFLINE-002, NFR-REL-001,
NFR-SEC-002/003 and NFR-MAINT-002 gain truthful resume, bounded recovery,
foreground cancellation, echo-wake restoration, optional readiness feedback,
accessible restart and conservative interpretation. 673 Flutter cases (21 new),
25 native app cases (3 new), clean analysis and 10-file formatting pass. Existing
reader assertions remain, with its resume-count expectation updated for deliberate
echo recovery. [Exact Android/physical results](VISION_AI_RELIABILITY_2026-10-21.md).
Physical accent/noise/output evidence is not inferred from automated tests.

## Module 74 verification amendment — 2026-10-21

FR-001/013/014/019/022; NFR-ACC-001/002, NFR-SEC-002/003, NFR-REL-001 and
NFR-MAINT-002 gain fresh-phone circle consistency, explicit setup/consent capture
gates, local-only activation without cloud client/recorder, saved-mode preservation
and unsent-draft/key-removal regressions. 652 Flutter cases (6 new), 89 focused,
clean analysis/format and debug build pass. [Exact artifact/deployment evidence](SMART_AI_FRESH_PHONE_2026-10-21.md).
Native/kernel/backend/Pi/model/provider rules remain; physical behavior is not
promoted from software evidence or the previous phone's acceptance.
Final 1.4.17 release/install/installed-byte/cold-launch checks pass on Pixel;
owner confirms circle and setup button. This verifies the reported cross-phone UI
correction, with audio/recognition/TalkBack acceptance still separate.

## Module 73 verification amendment — 2026-10-21

FR-003/004/013/014/015/019/021/022, NFR-ACC-001/002, NFR-OFFLINE-002,
NFR-REL-001, NFR-SEC-002/003 and NFR-MAINT-002 gain spoken progress/truthful
controller results, visible-screen deterministic routing/polite grammar, direct
Smart AI idle/paused controls and preserved capture ownership. **646 Flutter/22
native app tests**, clean analysis/format, both ARM64 builds and verified signed
1.4.16/code 4056 artifact pass. [Exact command/device evidence](VISION_AI_COMMANDS_2026-10-21.md).
No camera upload/unprompted provider request or new physical acceptance claim.
Later owner-directed Pixel 9 Pro fresh installation confirms FR-001 package/launch:
installed bytes match, 1.4.16/code 4056, MainActivity foreground, live process and
zero fatal markers. First launch reached permission UI, so 362 ms is not app-only
cold latency. No new voice/TTS/haptic/paired-Pi acceptance is promoted.

## Module 72 evidence — 2026-10-21

ADR-073 / [verification](SMART_AI_READY_CUE_2026-10-21.md) strengthen
FR-013/014, NFR-ACC-001/002, NFR-REL-001 and NFR-MAINT-002: actual-recording-
then-cue order, local vibration+sound test, independent outputs, bounded resource
lifetime, generation-safe replacement, foreground/cancel cleanup, labelled
fallback on hardware failure and continued usable recording. 615 Flutter cases,
clean analysis/format and 21 native app cases pass (9 Dart/4 Kotlin additions).
1.4.15/code 4055 debug/release builds, matching-signer/alignment/non-debuggable
metadata and delivery bytes also pass. New native bridge touches only Smart AI
feedback registration/lifecycle. Vision
AI and provider/model/recording/language policies remain unchanged. Owner chose
APK delivery for later testing, so physical haptic/chime acceptance is pending;
no device/internet/latency/TalkBack requirement is wholesale promoted.

## Module 71 evidence — 2026-10-20

ADR-072 / [verification](SMART_AI_CIRCLE_2026-10-20.md) strengthen
FR-013/014/015/019/022, NFR-ACC-001/002, NFR-SEC-002/003, NFR-REL-001 and
NFR-MAINT-002. Latest-question English/Urdu instruction preserves the exact base
prompt; hold/release/cancel, recording-start cue, local pause/resume, interrupt,
capped-recording release and exact goodbye-before-LLM/audio-before-Home have
regression coverage. Semantic activation, named button alternatives and narrow
2× layout remain tested. 591 Flutter cases pass (20 new), analysis/format clean,
1.4.13 debug/release builds and data-preserving verified installation pass.

New physical bilingual switching, haptic/hold/release, pause/resume and goodbye
acceptance is pending owner observation. Existing 1.4.12 Urdu/replay acceptance
is not promoted to those new behaviors. Vision AI/native/backend/Pi sources and
all 31 Stitch references are unchanged. Accessibility/full latency/accent/noise/
local wake requirements remain bounded by their physical matrices.

## Module 70 evidence — 2026-10-19/20

Owner-approved Smart AI cloud speech and explicit Groq-only answers are recorded
in ADR-070/071. [Verification](SMART_AI_CLOUD_AUDIO_2026-10-19.md) addresses
FR-013/014/015/019/022, NFR-SEC-002/003, NFR-REL-001 and NFR-MAINT-002:
separate encrypted keys/provider choice and consent, sequential bounded 16 kHz
mono capture, Whisper large v3, exact prompt, Groq GPT-OSS 20B/no returned
reasoning, deterministic controls, local TTS, clip cleanup/cancellation, offline
Urdu/English voices and local replay without another API call.

571 Flutter tests, clean analysis/format, 1.4.12 builds/install/installed bytes/
non-debuggable flags/cold launch pass; prior native 13 pass after the only native
cache method change. Physical Start/Cancel passes; owner confirms Urdu STT and
Urdu response text. Urdu voice pack installed; owner confirms 1.4.12 pronunciation/replay both work.
Physical local capture/cancel, background/resume and settings reentry pass with
no uploads; app process alive and zero current-process fatal markers. Vision AI/native recognizers/shared TTS/backend/Pi hashes
preserved. AgentRouter client denial is distinct from invalid keys. No broad
accent/noise/TalkBack/end-to-end-latency requirement promotion is inferred.

## Module 69 evidence — 2026-10-19

[Verified software and bounded physical checks](HOTSPOT_AND_GEMINI_VERIFICATION_2026-10-19.md)
strengthen FR-008/010/011/012/013/019/021/022, NFR-OFFLINE-001/002,
NFR-REL-001, NFR-SEC-002/003/004 and NFR-MAINT-001/002. Physical phone-hotspot
NSD, exclusive enrollment, authentication, settings acknowledgment, Running,
OV5647/real NCNN, retained trust, audible phone test and owner-confirmed object
speech are observed. Phone/laptop pairing and a typed Ollama reply also pass on
the shared hotspot. Direct
Gemini consent/Keystore/text-only/no-tools/error/cancellation has automated
evidence, not live-key acceptance. Current under-voltage/throttling and remaining
offline/recovery/TalkBack/fallback/performance gates prevent wholesale physical
requirement promotion. Owner still rejects speed after the deployed Pi profile;
38 Pi cases (five new current/history power vectors) and three real cross-stack
cases pass. The 2 A adapter still reports active power throttling under load.
Existing statuses remain deliberately bounded.

## Module 68 speech evidence — 2026-10-16

[Speech verification](SMART_AI_SPEECH_VERIFICATION_2026-10-16.md): follow-up 128
backend/466 full Flutter and 88 focused assistant tests pass, clean analysis;
earlier 13 native app tests and ARM64 debug build pass. Evidence supports
FR-013/014/019/022, BR-003 and NFR-REL-001/
NFR-MAINT-002: language correctness, rejection before query routing, TTS/capture
sequencing, clip cleanup, background cancellation and speech-recovery handling.
Synthetic medium corrects one rendering of the university question, but errors
remain (ISSUE-074). No physical status is promoted. The already-present paired
manual laptop-audio path is now explicitly approved in ADR-068's addendum, with
pre-capture disclosure and deletion after processing. ISSUE-075's scope conflict
is resolved; physical recognition/deletion acceptance remains open. No new
transport or cloud speech provider is introduced.

## Demonstration artifact — 2026-10-15

The [2:50 narrated walkthrough](../deliverables/demo/README.md) presents
FR-003/004/005/008/009/010/012/013/015/019/021/022 and BR-001/002. Its actual
emulator observations are Mobile Detecting, synthetic on-device OCR into six
reading lines and a successful typed local battery-status result. Duration,
decoding, captions and automatic hover borders are verified in the linked
media report. This is demonstration coverage, not new feature acceptance:
audio output is unverified/unavailable in this emulator (ISSUE-072), wearable
and laptop pairing are interface-only, and physical acceptance statuses below
remain unchanged. A narrow Scanner document-header defect is ISSUE-073.

## Physical phone Smart AI runtime evidence — 2026-10-15

FR-019/021/022 gain actual physical-phone pairing, reachable status and one
synthetic typed local-Ollama reply through the existing private-LAN endpoint
192.168.10.5:8765. The backend was already healthy; the unpaired phone still used
the old connection preset. Existing owner-code pairing corrects this without
source changes or authentication bypass. Phone microphone recognition, TTS
sound, Gemini and outage recovery remain unverified by this check. Pairing
rotates the single backend credential, replacing the emulator's old token.

## Rescan framing follow-up — 2026-10-15

Owner correction to FR-015 Scanner voice behavior: rescan/restart returns to
camera framing with the old page cleared. Capture waits indefinitely for a
later explicit Scan command/button. Regression coverage checks both aliases,
no timer-based capture, later OCR/reading, duplicate suppression and cleanup.
Evidence is in the [reader follow-up](READER_VOICE_VERIFICATION_2026-10-15.md#rescan-framing-follow-up).
No new physical acceptance claim is made.

## Module 67 verification — 2026-10-15

[Reader voice verification](READER_VOICE_VERIFICATION_2026-10-15.md): 459 Flutter
and 13 native app tests pass; analysis and debug/release builds pass. Evidence
supports FR-013/014/015, NFR-OFFLINE-002, NFR-REL-001 and NFR-MAINT-002 with
stable guarded reader proposals, live-widget controls during held speech,
printed-command/wake rejection, cancellation ownership and stale/background
guards. Recognition remains local; no raw audio is stored or uploaded.
This does not close physical accent, speaker overlap, AEC or TalkBack gates.

## Module 66 verification evidence — 2026-10-15

[Voice/connection verification](VOICE_FIXES_2026-10-15.md): 404 Flutter tests,
108 backend tests and 9 native app tests pass. New evidence covers native and
Dart Scanner restart aliases, actual synthetic capture/OCR/cleanup/reading,
duplicate-capture prevention, complete explicit session exits, delayed saved
credentials, overlapping health checks, unpairing, timeout/retry and unsent OCR
drafts. Smart AI reachability does not replace explicit pairing or prove a
provider can answer. Release 1.4.3 installs and opens Smart AI on the emulator.
Runtime follow-up adds real emulator owner-code pairing, reachable status and
one successful synthetic typed request/reply through local Ollama `llama3.2:3b`.
This supports FR-019/021/022; physical voice and outage acceptance remain open.
Later phone deployment strengthens FR-001 startup evidence: owner-authorized
TECNO LE6/API 30 installation of release 1.4.3/code 4043, matching installed
checksum, non-debuggable flags, successful cold launch and resumed welcome UI.
This does not verify physical Scanner/voice/TalkBack or Pi workflows.

Software evidence addresses FR-013/015/019/021/022, NFR-OFFLINE-002,
NFR-REL-001, NFR-SEC-003 and NFR-MAINT-002. FR-001 gains current emulator
release startup/navigation evidence. No physical acceptance status is promoted;
the existing phone/Pi, voice, Scanner and TalkBack gates remain open.

## Module 65 verification evidence

[Hotspot and speech verification](HOTSPOT_VERIFICATION_2026-10-09.md): 393 Flutter
and 33 Pi tests pass. Cross-stack tests exercise enrollment/authentication,
settings, running detection, spoken object text, heartbeats, reconnect and
revocation with normal and ±365-day phone clocks. Golden HMAC vectors cover
trailing timestamp zeros and small health values; 10,000 synthetic numeric
encodings match Dart. Audio tests cover accessible local testing, failure,
pause/stop/background/disconnect cancellation and stale completions.

Software evidence strengthens FR-008/010/011/012, NFR-ACC-001,
NFR-SEC-002/004 and NFR-MAINT-002. No physical status is promoted: TECNO BG6/Pi
hotspot discovery/routing, actual phone/Pi speakers and native inference remain
open. Both updated components must be deployed for the complete repair.

Last reviewed: 2026-10-15

Statuses: Not Started, In Progress, Blocked, Implemented, Verified, Deferred.
Implemented means code and automated evidence exist while required physical
acceptance remains open.

## Module 64 verification evidence

The [whole-project audit](PROJECT_AUDIT_2026-10-09.md) supersedes historical
command counts for the current workspace. Software evidence addresses
FR-015/018/020/021/022 and NFR-SEC-002/003/004, NFR-REL-001 and NFR-MAINT-002.
No physical requirement status is promoted by this audit. Aggregate native plugin
tests and Android lint remain dependency-blocked. Battery and device-command
acceptance, server Confirm/Cancel with the updated backend, and every existing
phone/Pi manual gate remain open.

| ID | Requirement | Implementation/evidence | Status | Remaining verification |
|---|---|---|---|---|
| FR-001 | Launch native Flutter UI | signed ARM64 `1.4.2`; TECNO BG6 USB update, live focused process and no app-scoped fatal marker; Module 56's 1,191 ms cold foreground launch evidence retained | Verified on target phone | preserve regression |
| FR-002 | Explain/request camera permission | permission flow, local-processing copy, and Scanner camera-denial/retry guidance | Implemented | physical denial/revocation and settings recovery |
| FR-003 | Select Mobile/Wearable mode | Riverpod, persisted settings, route tests | Verified | Pi physical use |
| FR-004 | Start/pause/resume/stop Mobile assistance | `AssistanceController`, integration tests, cleanup | Implemented | repeated physical sessions |
| FR-005 | Capture/process frames on-device | CameraX, bundled YOLOv8n LiteRT; TECNO BG6 live preview/Detecting/one result passed | Implemented | alignment and sustained performance |
| FR-006 | Generic person detection only | COCO person class; no face/identity code | Verified | preserve |
| FR-007 | Estimate risk, not exact distance | bounded relative visual heuristic and tests | Verified | real-scene usefulness |
| FR-008 | Offline spoken and bounded haptic alerts | local TTS, finite patterns, cooldown/rate limits; authenticated Pi alerts use phone TTS with failure reporting and Pi-local disconnect fallback; Modules 69/76 include owner-confirmed phone test and object speech on TECNO/Pixel | Phone audio accepted on TECNO and Pixel; broader hardware checks open | haptics, Pi fallback audibility, induced TTS failure and full lifecycle matrix |
| FR-009 | Configure/persist sensitivity and feedback | local validated settings and tests | Verified | physical comparison |
| FR-010 | Discover/enroll/control local Raspberry Pi | Bounded NSD, exclusive enrollment, Keystore credential and authenticated protocol; Module 69 TECNO and Module 76 Pixel complete physical discovery/enrollment/settings/Running; direct hotspot TCP confirmed | Physical pairing/control verified on TECNO and Pixel | full hotspot/DHCP-address-change matrix remains open |
| FR-011 | Recover from camera/model/output/Pi errors | typed failures, cleanup, retry/reconnect and Wi-Fi-up revival tests; Module 76 restores fresh OS service/model/runtime and verifies saved Pixel trust reconnect | Software verified; restoration physically verified | induced hardware/TTS failures, restart and full hotspot-outage matrix |
| FR-012 | Accessible settings/help/about/running UI | Module 63 single action names, contextual Back/Help/navigation, selected settings/modes/devices, and live Help step feedback; shared labels cover Mobile/Wearable actions | Implemented | physical TalkBack and blind-user review |
| FR-013 | Foreground hands-free and manual voice assistant | one-time microphone grant; final-only “Hey/Hi Vision AI” opens a persistent foreground command session; goodbye restores wake-only mode; focused app/scanner graphs; safe cancel/join route switching; serialized manual alternative | Implemented | owner one-wake/multi-command, false-command, repeated profile-switch, crash-log, and TalkBack acceptance |
| FR-014 | Local speech transcription with owner-approved Smart AI exceptions | Vision AI/hands-free remain phone-local; paired legacy Smart AI can use disclosed laptop Whisper; optional ADR-070 Smart AI-only capture uses Groq whisper-large-v3 after separate consent; bounded clips/deletion/cancel tests pass | Implemented | physical varied voices, accent, noise, new provider/model access and microphone-distance matrix |
| FR-015 | Voice/text control of app settings | phone-local semantic parser with whole-word matching and higher fuzzy threshold; persistent session covers app settings plus Scanner capture, start/pause/resume/stop, line navigation, spelling, speed, camera, and torch; Scanner manual torch choice now overrides low-light automation | Implemented | physical multi-command and Scanner spoken matrix |
| FR-016 | Voice/text control of Mobile Mode | phone-local transcript routing to real status/start/pause/resume/stop controller checks | Implemented | phone camera/permission states |
| FR-017 | Voice/text control of Raspberry Pi | phone-local transcript routing to real discovery/status/connect/disconnect/session tools; manual and voice paths retain authenticated trusted-phone credentials | Implemented | hardware acceptance |
| FR-018 | Confirmation for sensitive actions | tool-spec enforcement, accessible Confirm/Cancel UI, Module 64 deferred server execution bound to user/request/tool, single-use/replay/cancel/mismatch tests | Verified in software | deploy updated backend; physical TalkBack/voice confirmation matrix |
| FR-019 | Hybrid AI selection | Existing Vision AI/Gemini/Ollama paths preserved; configured Smart AI view independently selects Groq/AgentRouter with exact owner prompt/models; deterministic user controls precede conversation and cloud replies never execute tools | Implemented | live cloud key/model/voice/latency, paired multi-turn, Gemini/outage and ISSUE-074 accuracy acceptance |
| FR-020 | Local assistant personal utilities | explicit SQLite tools; Module 64 real schedule update, confirmed memory deletion, completed-reminder filter and database-effect regressions | Implemented | end-to-end user acceptance |
| FR-021 | Clear assistant connection/settings UI | `/assistant`, `/assistant/connection`, `/assistant/settings`, route/widget tests | Verified | physical TalkBack |
| FR-022 | Truthful provider/connection/error state | health schema and typed Flutter failures | Implemented | offline/provider outage UI |
| NFR-ACC-001 | TalkBack-compatible controls | Module 63 exact label/state and actual accessibility-tap tests; 14 Scanner controls, changing Start/Pause/Resume, assistant voice/typed controls, adjustable cooldown with seconds; native tooltip names | In Progress | manual TalkBack and blind-user review |
| NFR-ACC-002 | Large text/touch targets | bounded nonlinear scaler, Scanner action groups stack at 2× scale, reader widget regression test | In Progress | physical font/display scaling |
| NFR-OFFLINE-001 | Core assistance works without internet | bundled Mobile model and authenticated local Pi event/audio workflow independent of assistant providers; same routed LAN is required, internet is not | Implemented | WAN-disabled physical phone/Pi session |
| NFR-OFFLINE-002 | Assistant has fully local control path | typed and spoken app controls execute on-phone through deterministic tools; Gemini/Ollama backend is optional conversation only | Verified in automated/controller and Android build evidence | WAN-disabled physical spoken-command session |
| NFR-PERF-001 | Practical latency/resource use | Mobile gate/buffers; bounded audio; one local model owner | In Progress | phone/Pi mean/p95/thermal |
| NFR-SEC-001 | Raw frames never uploaded/stored/logged | no assistant frame input; Scanner deletes temporary capture after OCR or on every exit path before playback; Ask AI passes text only to an editable draft and requires explicit Send | Implemented | physical cache/file inspection after interrupted scan and live assistant disclosure review |
| NFR-SEC-002 | Secrets protected | assistant/Pi tokens and personal Gemini/Groq/AgentRouter keys use separate Android Keystore AES-GCM entries; backend environment keys use SecretStr; no shared client secret or embedded Pi login; secure write/delete failures and redaction tested | Implemented | physical Keystore/revocation and APK scan regression |
| NFR-SEC-003 | Minimize assistant data | Vision AI/hands-free remain local; disclosed legacy paired audio uses laptop Whisper; owner-approved Smart AI-only Groq clips are deleted locally after STT/failure; AgentRouter/Gemini receive bounded text only; cloud-provider retention disclosed; no persisted new conversation | Implemented | physical interrupted-clip cleanup and live provider request/retention disclosure review |
| NFR-SEC-004 | Local transport boundary disclosed | exclusive private-peer first enrollment, HMAC auth, private-host validation, no manual-IP bypass, trust-on-first-use warning; phone-hotspot design and physical gate documented | In Progress | TLS/pinning and physical phone/Pi hotspot acceptance remain open |
| NFR-REL-001 | Safe provider degradation | deterministic controls and Gemini-to-Ollama fallback tests | Implemented | forced live Gemini outage |
| NFR-MAINT-001 | Platform logic outside widgets | domain service/repository interfaces and Riverpod orchestration exist; Scanner still owns camera-plugin initialization in its widget (ISSUE-052) | In Progress | move Scanner camera lifecycle into an injected service |
| NFR-MAINT-002 | Tests/docs accompany work | Module 64 full automated suites, clean Dart/Ruff checks, model/local-provider smoke, fresh native app tests, debug/release APK evidence and exact blockers in audit report; Module 65 adds 34 hotspot/audio regressions and verified emulator update | Verified for Modules 64–65 software evidence | physical matrices; aggregate native/lint dependency blockers |
| NFR-RESP-001 | Responsive native UI | scrollable layouts, nonlinear scale, 2x tests; no WebView | In Progress | portrait/landscape phone |
| CON-001 | Native Flutter/no WebView | dependency/source/route review | Verified | preserve |
| CON-002 | Limited owner-authorized assistant exception | 2026-08-14 specification amendment permits paired auth and optional Gemini text only | Verified scope decision | preserve exclusions |
| CON-003 | No Firebase/analytics/remote config/cloud vision | source/dependency review; Gemini is reasoning-text exception only | Verified | preserve |
| CON-004 | Settings remain local | SharedPreferences plus deliberate laptop-local assistant SQLite; no cloud sync | Verified | reboot persistence |
| CON-005 | Preserve Stitch sources | no Stitch reference file edited/deleted | Verified | repeat inventory |
| BR-001 | Assistive aid, not replacement/navigation | safety copy in primary screens and assistant docs | Verified | preserve |
| BR-002 | Familiar identity and exact distance excluded | generic class and relative-risk terminology only | Verified | preserve |
| BR-003 | No background/lock-screen or OS-wide assistant control | wake/conversation listener is bounded to the foreground open app; lifecycle stop/restart and manual-mic ownership are serialized | Implemented | battery/thermal and repeated lifecycle acceptance |
