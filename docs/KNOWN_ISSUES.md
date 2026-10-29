# Known Issues

## Project-guide clarification — 2026-10-22

ISSUE-065 remains an evidence gap, not verified fine-tuning. The owner's new
request treats the claim as potentially unperformed; no dataset/run/checkpoint/
held-out evaluation/export lineage is supplied. Corrected the older Markdown
presentation introduction, training section, slide/viva wording and claims table
to describe pretrained integration and proposed training. Its original Word
export is historical and superseded by the [new complete guide](../deliverables/AI_Blind_Assistant_Complete_GPT_Guide.md).
No model/source or requirement acceptance changes. Do not invent training details.

## Module 76 physical follow-up — 2026-10-22

Owner-confirmed OS reflash removed the prior Pi installation. Existing deployment
is restored and Pixel enrollment/authentication/Running/camera/model verified;
this is not an unresolved network/runtime blocker. Service processes real frames
with zero restarts. ISSUE-076 remains open: current 0x50005 and roughly 600 MHz
under load. Owner confirms test audio and object announcements on Pixel;
broader accuracy/TalkBack acceptance remains open.
Removing the phone app closes its link; Pi detection continues. Latest observed
Android exit is USER REQUESTED / REMOVE TASK with no matching crash diagnostic;
do not relabel that as a crash or claim background phone alerts. [Evidence/next action](PIXEL_PI_RESTORE_2026-10-22.md).

Module 75 physical follow-up: owner confirms repeated commands and the ready cue
both work on installed Pixel 1.4.18. This bounded check does not close broader
accent/noise/TalkBack acceptance.

## Module 75 Vision AI listening reliability

- **ISSUE-085 — Rejected echo wake/failed resume could strand capture:** fixed
  in software through explicit resume acknowledgement, echo/empty-callback
  restoration, serialized handling, lifecycle generation guards and two-attempt
  recovery. Optional actual-readiness cue and accessible manual restart added.
  673 Flutter/25 native cases and clean analysis pass. Physical accent/noise,
  audible/felt cues and TalkBack remain separate acceptance gates; ordinary
  commands still pause during feedback. Do not claim error-free recognition.
  [Build/device results and next action](VISION_AI_RELIABILITY_2026-10-21.md).

Last reviewed: 2026-10-22



## Module 74 cross-phone presentation

- **ISSUE-084 — Fresh phone silently showed legacy Smart AI UI:** Pixel's
  installed 1.4.16 hash exactly matches delivery. Missing cloud keys selected a
  different screen. Fixed in software by retaining the circle/setup state,
  disabled question capture, local guide/cue/controls and explicit legacy choice.
  Saved Gemini/laptop modes remain. 652 Flutter cases/clean analysis and debug
  build verify behavior; [release/install/physical evidence](SMART_AI_FRESH_PHONE_2026-10-21.md)
  confirms verified 1.4.17 installation and the owner's explicit circle/setup
  acceptance. **Resolved; owner accepted UI.** Keys/opt-in and Pi trust remain per
  phone; never embed shared keys or infer consent to make the interface configured.

## Module 73 physical command gate

- **ISSUE-083 — New local-command acoustic acceptance pending:** 646 Flutter
  and 22 native app tests/build/artifact checks verify spoken progress/state
  handling, visible-screen routing, polite grammar and direct Smart AI idle/paused
  controls. Physical recognition with the owner's accent/noise, audibility and
  TalkBack require the short check in [the report](VISION_AI_COMMANDS_2026-10-21.md).
  Use typed local controls or named buttons if recognition is unavailable. No
  paid/provider test is needed. Pi power issue ISSUE-076 remains independent.
  Owner redirected to Pixel 9 Pro: 1.4.16 fresh install/installed-byte/foreground
  checks pass; that phone needs its own Smart AI opt-in/keys and Pi trust. Physical
  acceptance remains pending on the new target.

## Module 72 physical cue gate

- **ISSUE-082 — Smart AI ready haptic/chime acceptance pending:** Owner still
  feels no haptic in the installed app and requests a readiness sound. New
  isolated native accessibility vibration + local prompt tone has 615 Flutter/
  21 native passing tests, clean analysis/format, 1.4.15 debug/release builds
  and signed/aligned non-debuggable APK verification. The old plugin used alarm
  attributes; this is not proof of the physical cause. Native request success
  does not prove felt/audible output. Owner requested an APK for later testing;
  later matching-signer 1.4.15 installation/foreground checks passed, but
  explicit physical acceptance is still pending. Test listening vibration and sound without
  recording/API use. Check media volume for sound; recording stays usable if
  either cue cannot start. Existing Vision AI/system settings remain unchanged.

## Module 71 physical gate

- **ISSUE-081 — Smart AI circle follow-up active:** 1.4.13 has 591 passing
  Flutter cases and verified builds/install, but the owner rejects its vibration
  and language behavior. English input is already transcribed into Urdu, so an
  answer-only language prompt cannot fix the source error. Goodbye was spoken
  without a recording. The owner authorizes local Vision AI listening alongside
  button-only cloud Smart AI. New foreground local goodbye, capture handover,
  bounded pulse, accessible labels/spoken help and explicit transcription-language
  overrides are being implemented; new acceptance remains open. Automatic STT
  language inference, accent/noise and TalkBack are not guaranteed by unit tests.

## Module 70 live gates

- **ISSUE-080 — Smart AI provider/physical acceptance:** AgentRouter's observed
  401 is `unauthorized_client_error`; owner confirms enabled token/model, so
  invalid credentials are not established. Owner selected Groq speech/answers.
  Groq metadata returns 200 and owner confirms Urdu recognition/answer text.
  1.4.12 fixes the English-only speech mismatch with isolated offline Urdu voice
  selection/restoration and local replay. Urdu pack installed; owner confirms Urdu pronunciation/replay both work.
  Physical Start/Cancel, capture-background/resume and settings reentry pass. 571 Flutter tests/clean analysis/both builds and
  installation verified. Optional AgentRouter remains client-approval gated,
  without impersonation or retries. Broader accent/noise/TalkBack/latency and
  handover acceptance remain. Original HTTP 400 size misdiagnosis is corrected.
- ADR-070/specification/agent guide resolve the older blanket cloud-audio
  conflict only for owner-consented Smart AI Speak → Groq. Vision AI audio,
  camera frames, OCR and wake controls are excluded; provider retention is
  disclosed and local deletion makes no provider-copy deletion claim.

| ID | Severity | Issue | Current evidence/workaround | Status |
|---|---|---|---|---|
| ISSUE-003 | Medium | Earlier audits reported that the workspace was not a Git repository. | Current audit confirms `main` at `701fea9` with `origin/main`; preserve uncommitted user changes. | Resolved |
| ISSUE-004 | Low | Plain Flutter commands can stall in version/network checks, and `--no-pub` can preserve a debug/test plugin registrant for release. | Use `flutter --no-version-check`; release builds must run Flutter dependency/plugin preparation without `--no-pub`. | Open / mitigated |
| ISSUE-005 | Medium | `integration_test/app_startup_test.dart` has no Android-device result in this pass. | A phone appeared after release installation. Running the debug instrumentation build could replace/conflict with the signed release, so only data-preserving release install/direct-start smoke was performed; do not claim `IT-STARTUP-001` passed. | Open |
| ISSUE-006 | High | Stitch references contain remote assets and incomplete semantics. | Native production UI does not load them; Stitch files remain unchanged references. | Mitigated |
| ISSUE-008 | Medium | Physical TalkBack behavior is unverified. | Module 63 verifies precise single labels, selected/disabled state, semantic activation, slider units, and dynamic reader controls; 351 Flutter tests pass/1 environment skip. `adb devices -l` reports no attached device; manual screen-by-screen review with a blind user remains required. | In Progress |
| ISSUE-009 | Medium | Physical large-text/orientation review is unverified. | Native layouts pass 2.0 text-scale tests; physical review remains. | In Progress |
| ISSUE-012 | Low | `flutter doctor -v` reports unrelated XAMPP scan permissions and incomplete Xcode. | Neither blocks Android debug builds. | Open |
| ISSUE-013 | High | Physical Android acceptance is incomplete. | ARM64 Android 13 install/cold-start/CameraX Detecting and clean-close smoke passed with no app-scoped fatal log. Box quality, TTS, haptic, TalkBack, permission matrix, offline and performance checks remain. | In Progress |
| ISSUE-014 | Medium | Flutter TFLite packages were unavailable in the original offline cache. | Existing Kotlin MethodChannel uses verified non-transitive LiteRT 2.1.5. | Resolved by design |
| ISSUE-018 | Low | Inference diagnostics are internal. | Controller exposes processed/dropped/timing counters; no user-facing debug panel was added. | Open |
| ISSUE-019 | Medium | The ARM64 API 37 emulator became offline after the smoke run. | Current logs captured CameraX, model/XNNPACK, and `Detecting`; sustained emulator claims were not made. | Open |
| ISSUE-020 | Medium | The repository initially failed analysis/build because `wearable_providers.dart` was missing. | Provider composition restored; all 171 tests and analyzer pass. | Fixed |
| ISSUE-021 | Medium | Android NDK 28.2.13676358 originally lacked `llvm-strip`. | The exact official r28c `llvm-objcopy`/`llvm-strip` tool was restored in the host SDK; signed ARM64 release build now passes. A normal complete side-by-side NDK install is still preferred on another Mac. | Resolved locally |
| ISSUE-022 | Low | `flutter_tts` and ML Kit plugins apply the legacy Kotlin Gradle plugin. | Flutter 3.44 warns about future incompatibility; the current build passes. | Open |
| ISSUE-023 | High | Full Mobile Mode physical acceptance is pending. | Real boxes/feedback/offline/lifecycle/performance/thermal checks remain in `TESTING.md`. | Open |
| ISSUE-024 | Medium | LiteRT Android 2.1.6 conflicts under AGP 9. | Its AAR namespaces collide; keep verified non-transitive 2.1.5 until packaging is compatible. | Open upstream / mitigated |
| ISSUE-025 | Low | LiteRT FlatBuffer exports are not byte-for-byte deterministic. | Pin dependencies and source; validate tensors/parity and record the exact packaged hash. | Documented |
| ISSUE-026 | Low | `litert-torch` logs a training-mode warning during export even after `model.model.eval()`. | The script asserts evaluation mode; exported inference tensor `[1,84,2100]`, warm-up, finite boxes, and PyTorch/LiteRT parity pass. Treat future tensor/parity changes as failure. | Open upstream / mitigated |
| ISSUE-027 | Medium | Release manifest includes network permissions despite older Module 14 records saying otherwise. | Current permissions are required only by the separately present local-LAN wearable module. Mobile Mode has no network call or runtime download. Living docs now state this boundary. | Resolved documentation conflict |
| ISSUE-028 | High | Earlier Raspberry Pi deployment/enrollment was blocked by endpoint reachability. | Module 69 verifies the owner's Pi SSH identity, deploys the service/model and completes actual phone-hotspot discovery/enrollment/Running. The app uses its own paired protocol, without a Pi login password or SSH implementation. | Original reachability/deployment blocker resolved |
| ISSUE-029 | High | OV5647 has a known intermittent CSI timeout and no two-session result in this pass. | Bounded service recovery and `camera_smoke_test.py` exist. Run two independent sessions on the Pi; do not claim a software hardware fix. | Open |
| ISSUE-030 | Medium | Raspberry Pi NCNN/aarch64 compatibility and real OIV7 inference required physical verification. | Module 69 installs official ncnn 1.0.20260526 on aarch64/Python 3.13.5; all finalized artifact hashes and real [605,2100]/601-class warm-up pass. Phone reports Camera Active/Model Ready with live detections. Sustained performance remains ISSUE-076. | Runtime/model compatibility verified on the Pi |
| ISSUE-031 | Medium | Wearable Mode complete physical Android acceptance remains incomplete. | Module 69 verifies physical TECNO BG6 hotspot NSD, enrollment/authentication, synchronized settings, Running, persisted trust after app update/reboot, clear phone audio test and owner-confirmed real object speech. TalkBack, full outage/WAN-off/recovery and sustained performance remain separate gates; owner still rejects detection speed. | Physical integration partially verified |
| ISSUE-032 | Medium | No vibration motor or GPIO driver was specified for the wearable. | Module 56 prefers phone audio and keeps Pi speech as disconnect fallback. UI still reports Pi haptics unavailable and does not guess a pin/circuit; Mobile Mode vibration remains independent. | Open hardware scope |
| ISSUE-033 | Medium | Protocol v1 local WebSocket traffic is authenticated but not confidential. | HMAC, nonces, replay checks, private endpoint validation, and no TLS bypass are implemented. Pair only on a trusted LAN; never port-forward. | Accepted boundary (ADR-032) |
| ISSUE-034 | Low | The final shareable release is ARM64-only, not a universal/multi-ABI APK. | The target physical Android phone class is ARM64. Building all ABIs would require a complete multi-architecture NDK installation and would materially increase the artifact. | Accepted release scope (ADR-036) |
| ISSUE-035 | Low | `com.example.ai_blind_assistant` is a technically valid but generic application ID. | It is consistent across the existing app and signed APK. Changing it now would create a different installed application and require an owner-selected permanent reverse-domain identity. | Open product decision |
| ISSUE-036 | High | The former experimental assistant conflicted with the initial scope and lacked native audio/secure credentials. | Owner-approved amendments and ADR-039/041 now govern it. Dedicated on-device speech, Keystore storage, allow-listed tools, Gemini disclosure, and Ollama fallback are implemented and tested. | Resolved by Module 25 scope and architecture |
| ISSUE-037 | Low | Backend tests emit Starlette/httpx and Python 3.14 asyncio deprecation warnings. | All 49 tests pass with 29 warnings. Use a supported Python 3.11-3.13 environment for release service operation and migrate dependencies when upstream support is available. | Open upstream / mitigated |
| ISSUE-038 | Medium | Android 17 introduces local-network permission protections for target SDK 37+. | Current target SDK 36 does not require `ACCESS_LOCAL_NETWORK`. Before targeting 37, choose the system NSD picker or implement the runtime permission flow and physically retest Wearable discovery. | Future migration |
| ISSUE-039 | Low | Current Android build reports future Gradle migration warnings (`flutter_tts` legacy KGP, legacy DSL flags and `aaptOptions`). | Flutter 3.44/AGP 9 builds pass. Migrate only with a compatible Flutter/plugin/AGP toolchain and rerun the full release matrix. | Open maintenance |
| ISSUE-040 | High | Assistant phone-to-laptop HTTP is authenticated but not confidential. | Private-host validation, one-time pairing and Keystore bearer storage protect authorization, not network confidentiality. Use only a trusted private LAN; never port-forward port 8765. Add pinned/managed TLS before hostile-network use. | Accepted local boundary / security work open |
| ISSUE-041 | High | Assistant and Scanner lack completed owner-observed voice/TalkBack and live Gemini-key acceptance. | Module 62 improves Scanner camera/reader/Ask AI reliability; 344 Flutter tests pass with 1 skipped and debug APK builds. The corrected reader, real OCR/TTS, multi-command, and Ask AI draft flow still need physical phone acceptance, plus accent/noise, audio-focus, provider-failure, and accessibility matrices. | In Progress |
| ISSUE-042 | Medium | The dedicated Pi test environment previously lacked test dependencies. | Module 65 verified `raspberry_pi/.venv` has pytest/zeroconf, all 33 Pi tests pass there, and `pip check` reports no broken requirements. Actual Linux-aarch64 NCNN/Picamera2 packaging remains a physical deployment check. | Development test environment restored in Module 65 |
| ISSUE-043 | Medium | Continuous foreground Vosk recognition has not completed false-wake/false-command, intended-accent, battery, or thermal acceptance and currently bundles English only. | Listener is foreground/unlocked only, uses complete “Hey/Hi Vision AI” final results before entering a persistent focused command session, and returns to wake-only mode on goodbye. `[unk]`, final-only activation, contextual grammars, and device AEC reduce noise risk, but the longer active window needs quiet/TV/fan testing. This TECNO reports NS/AGC unavailable. | In Progress |
| ISSUE-044 | High | The owner reported that the app sometimes closes unexpectedly during voice use. | Source review found a plausible native race: profile changes reflected a replacement recognizer into a running `SpeechService` and could close/reset Vosk while its decoder thread was active. Modules 53-54 use cancel/join/reset/restart sequencing, including active route changes; tests, release build/install, and cold launch pass. A tombstone-free repeated spoken cycle remains required before marking this resolved. | In Progress |
| ISSUE-045 | Low | Aggregate Android plugin unit tests remain blocked. | Module 64 used Android Studio Java 21.0.10: eight fresh app tests pass, but ten CameraX classes cannot fetch the SDK 36 Robolectric Android artifact because repo1.maven.org DNS resolution fails. Re-run with Maven access; do not count aggregate tests as passing. | Open dependency/network blocker |
| ISSUE-046 | High | Earlier Pi and phone were on unreachable university-network subnets. | Module 69 moves laptop/Pi onto the phone hotspot and verifies actual phone-to-Pi TCP/WebSocket, NSD, enrollment and Running. Current DHCP endpoints are recorded in the verification report, never hardcoded. | Original physical network blocker resolved |
| ISSUE-047 | High | Code-free first-phone enrollment is trust-on-first-use rather than verified Pi identity. | Enrollment defaults off in code, is explicitly enabled by the production env, accepts private/loopback peers only, atomically permits one active phone, and then closes. Perform first use on an isolated owner-controlled router/hotspot; a hostile LAN client could otherwise claim an unclaimed Pi first. Use local `ai-blind-pi revoke all` for lost-credential recovery. | Accepted owner-requested boundary / physical validation open |
| ISSUE-048 | High | TECNO BG6 hotspot NSD/mDNS and TCP required a real-device result. | Module 69 one-tap Connect discovers rpi3-ml and enters Running without a manual address; Pi ss confirms the phone hotspot peer. Full hotspot restart/DHCP-change matrix remains open. | Discovery/TCP verified on target hotspot; broader recovery open |
| ISSUE-049 | Low | Two assistant-controller unused imports. | Module 64 removed them; final full Flutter analysis is clean. Historical warning evidence remains in prior module records. | Resolved in Module 64 |
| ISSUE-050 | High | Full Pi priority-audio and fallback ownership needs physical acceptance. | Module 69 confirms actual Pi telemetry targets the phone, clear Test Phone Audio without false warning and owner-confirmed real detection speech. Owner reports poor responsiveness. Disconnected Pi-speaker fallback, full class/direction correctness and TalkBack overlap remain separate checks. | Phone test/actual object speech verified; quality/fallback acceptance open |
| ISSUE-051 | Low | The first Module 61 debug build reported SDK XML versions 3/4 tool mismatch. | Both debug builds passed (final assembleDebug 12.8 seconds); align Android Studio and command-line tools during environment maintenance. No SDK/plugin upgrades were added to the connection task. | Open environment warning |
| ISSUE-052 | Medium | Scanner camera-plugin initialization and capture still live in its presentation widget, contrary to the project's injected-platform-service rule. | Module 62 guarded its lifecycle and temporary files without a broad camera subsystem migration. Move camera ownership to an injected Scanner application/infrastructure service and retest permission, switch, stream, capture, background, and disposal on Android. | Open architecture debt |
| ISSUE-053 | High | Laptop pairing accepted invalid/empty/sentinel codes and exposed direct token issuance. | Module 64 restores mandatory owner one-time codes, conditional consumption and rejection tests; direct route removed. Restart/deploy the changed backend before relying on the repair. | Resolved in source; deployment pending |
| ISSUE-054 | High | Sensitive server tools executed before confirmation. | Module 64 defers server-owned proposals until matching authenticated user/request/tool acknowledgement; tests cover Cancel, replay, cross-user/mismatch and real deletion. No updated phone/backend pair was physically tested. | Resolved in software; physical acceptance open |
| ISSUE-055 | High | Assistant transport could forward saved credentials/text to fallback hosts and leave reply reads unbounded. | Module 64 confines requests to the selected private endpoint, checks/connects resolved IPs, disables redirects, bounds total time/size and late work, and propagates failures. Local HTTP regression tests pass; unencrypted-LAN limitation (ISSUE-040) remains. | Resolved in software |
| ISSUE-056 | Medium | Device commands fabricated battery status or claimed speech-rate/torch success without applying/checking it. | Module 64 adds an injected Android battery adapter, awaited speech-rate updates and mobile torch checks, with regression tests and Android build evidence. Actual phone behavior still needs acceptance. | Resolved in software; physical acceptance open |
| ISSUE-057 | Medium | Complete Android lint is unverified. | Java 21 lint fails because shared_preferences unit-test lint models require uncached AndroidX/MockK/Mockito/Guava dependencies. Initial online attempt stalled and was stopped; bounded offline attempt records exact missing artifacts in the audit. | Open dependency/network blocker |
| ISSUE-058 | High | A tracked SSH helper contained a plaintext password and automatic host-key acceptance. | Module 64 replaces it with interactive ssh-copy-id argument forwarding; no secret remains in the current helper. Previous Git revisions retain the old value. Owner must rotate it if still used; history was deliberately not rewritten. | Source repaired; credential rotation unverified |
| ISSUE-059 | High | Independent command/heartbeat counters produced OUT_OF_ORDER errors during otherwise healthy wearable sessions. | Module 65 reproduces this with real Flutter/Python sockets and stamps all signed traffic through one sequence counter. Module 69 deploys both endpoints and observes authenticated settings/Running/reconnect. | Resolved in software; deployed; full recovery matrix open |
| ISSUE-060 | High | Offline Pi/phone clock mismatch blocked enrollment and authenticated messages. | Module 65 seeds a monotonic session clock from Pi hello without changing system clocks or widening the two-minute replay window. Normal/±365-day clock tests pass. | Resolved in software; physical reboot gate open |
| ISSUE-061 | High | HMAC verification intermittently rejected whole-millisecond timestamps and small/exponential numeric values. | Module 65 preserves exact signed timestamp text and aligns Pi canonical numbers with Dart; golden vectors and 10,000 synthetic numeric comparisons pass. Also replaces unsupported client close codes with legal application codes. | Resolved in software; deploy app and Pi together |
| ISSUE-062 | High | Output handover/cancellation could leave Pi fallback speaking, start delayed phone speech, or resume recognition twice. | Module 65 stops fallback before phone feedback and invalidates shared TTS generations; pause/stop/mute/background/disconnect and late-failure tests pass. ISSUE-050 still requires real speakers. | Resolved in software; physical acceptance open |
| ISSUE-063 | Medium | Failed settings sync could claim connection success/start detection; failed Pi persistence could change live settings anyway. | Module 65 blocks combined Start on sync failure and serializes persist-before-live-update. Failure regression tests pass. | Resolved in software |
| ISSUE-064 | Low | Wearable documentation still described a hardcoded university-network IP after dynamic discovery was implemented. | Module 65 corrects current setup to discovery/current address and records the source conflict. Historical handoff evidence remains historical. | Documentation conflict resolved |
| ISSUE-065 | Medium | Completed household YOLOv8n fine-tuning is not established by training or deployment records. | Earlier owner-reported training wording is superseded by the 2026-10-22 clarification. Current metadata identifies pretrained sources; no actual custom run/checkpoint/held-out metrics/export lineage is established. Corrected the Markdown brief and delivered a current GPT guide; the older Word brief is historical. Claim pretrained integration and household post-processing; require real evidence before claiming training. | Open training-evidence gap; presentation wording corrected |
| ISSUE-066 | Low | Model integration/evaluation guides listed a stale general-model SHA-256 that conflicted with the current binary and generated metadata. | On 2026-10-12 direct shasum verification confirms db0e5be08cf48ac4701ef8bb3953b8c7a15af237ec1fd6e4c76501168b6ef7db. Both guide hashes now match; no model binary or metadata was changed. Historical parity checks remain historical. | Documentation conflict resolved |
| ISSUE-067 | Medium | Scanner voice restart was absent from the native grammar and rescan reset framing without capturing a new page. | Module 66 added native/Dart aliases. The owner's later framing correction now routes rescan/restart to Scan Another Page's reset/framing path, with no automatic photo; explicit Scan captures afterward. Synthetic widget tests verify waiting, subsequent OCR/reading, cleanup and no overlapping captures. | Resolved in software; physical speech/Scanner acceptance open |
| ISSUE-068 | Medium | Smart AI waited for a question before checking its saved backend. | Module 66 checks health/version on entry and after pairing, shares pending checks, times out, rejects stale results and keeps voice controls independent. Check-only Retry does not resend text; explicit first pairing remains required. | Resolved in software; paired physical acceptance open |
| ISSUE-069 | Medium | Bare bye/by and substring conversation matching could end an offline voice session from homophones or incidental speech. | Module 66 requires complete explicit exit phrases before semantic matching and aligns native grammar/backend routing; regression tests cover buy/by/bye, quoted commands, every feature context and persistent sessions. Stop listening also takes priority over Mobile detection stop. | Resolved in software; real accent/noise acceptance open |
| ISSUE-070 | Medium | Earlier wireless ADB incremental installation reported Success but left no queryable phone package; recovery reset its first-install timestamp. | No uninstall/data-clear command ran. A matching-development-key release-mode APK installed with --no-incremental -r; checksum and cold launch passed, but previous phone settings/pairing retention is unverified. Use non-incremental installs and verify the installed package; compare signer before transferring updates. Module 66 deployment was redirected to emulator only and uses the project release signer. | Mitigated; earlier phone data retention unverified |
| ISSUE-071 | High | Reader voice commands could wait indefinitely for silence or be confused by the document's own speech; stale TTS completion/cancellation could affect a replacement utterance. | Module 67 adds guarded stable reader proposals, active/recent sentence echo checks, per-turn speech ownership, safe spelling/rate changes and full regressions: 459 Flutter/13 native app passes, clean analysis and both builds. | Resolved in software; physical overlapping speech/AEC acceptance open |
| ISSUE-072 | Low | The dedicated API 36 demo emulator has no default TTS engine configured. | During video capture `tts_default_synth` returned `null`; actual synthetic OCR produced six lines, but reader speech later reported output failure. The video's reader note and delivery README disclose that narration was added locally. Configure an offline TTS voice and repeat audible output acceptance; this is not evidence of a physical-phone speech defect. | Open emulator setup; physical audio acceptance unchanged |
| ISSUE-073 | Medium | The Scanner Document Text header wraps into single characters at the demo emulator's 360-dp width. | Actual release capture after OCR shows the header/count compressed beside the Copy action, producing excessive vertical space; reading-line controls and subsequent result/action cards remain available. Evidence is retained in the ignored demo build review images. Repair the responsive header in a scoped application change and verify narrow width/2x text/TalkBack. No app change was made for the video task. | Open responsive-layout defect |

## Module 69 findings — 2026-10-19

- **ISSUE-076 — Pi power quality:** real phone telemetry and
  `vcgencmd get_throttled` return `0x50005`: current under-voltage and throttling
  as well as historical flags. Owner moved from laptop USB to a 5 V/2 A adapter;
  under camera/model load the same flags and about 600 MHz remain, against a
  requested 1.2 GHz. Camera/model run, but reliable performance is not accepted
  until stable Pi power is provided. Health booleans now ignore history-only
  bits (five regression vectors); raw flags remain available for diagnosis.
  Use the model-appropriate
  supply/cable per [Raspberry Pi power guidance](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html).
  Module 76 repeats current 0x50005/600 MHz after the fresh OS restore. Current
  supply is owner-confirmed laptop USB; an available 5 V/3 A mobile charger has
  not yet been tested. The earlier 5 V/2 A report is historical.
- **ISSUE-077 — Audible phone test showed false failure:** the original normal
  TTS budget allowed about 5.4 seconds for the test phrase. The owner heard it
  clearly, yet the app reported failure. A more conservative bounded budget and
  slow-success/missing-completion regressions pass; the final on-phone repeat
  displays Audio test finished without the warning. The owner confirms clear sound.
- **ISSUE-078 — Personal Gemini live verification:** no owner key is configured
  or requested through chat. Direct text-only transport/consent/storage/failure/
  cancellation are tested. Live provider access, free quota, response quality
  and physical speech remain to be tested after the owner enters their own key.
- **ISSUE-079 — Pi detection responsiveness:** the owner still finds detection
  too slow after the measured profile update. Eight real camera samples show
  mean inference 584.8→544.5 ms, but capture mean 175.0→227.5 ms; no overall
  latency gain or accuracy improvement is established. Live timing samples
  show 520–556 ms inference and 583–616 ms frame age under active power throttling.
  Preserve two-frame stability, bounded speech and the unchanged model. Resolve
  power first, then repeat a controlled before/after and owner acceptance.
- **Scope conflict resolved:** the owner's laptop-free API request supersedes
  backend-only key storage for personal user-entered Gemini only. ADR-069,
  specification and agent guide record Keystore/disclosure boundaries. No shared
  APK key, raw-audio/cloud-vision transport or model-executed app control is allowed.

## Highest-priority Next Resolution

Smart AI speech follow-up (2026-10-16):

- **ISSUE-074 — Recognition accuracy remains physically unaccepted.** The owner
  reports unrelated words for a Quaid-i-Azam University question. Module 68's
  medium model corrects one synthetic voice where base failed; a second voice
  still produces a wrong name and another clip mishears an ordinary noun.
  Low-confidence rejection cannot catch confidently wrong names. Hands-free
  remains English Vosk, independent of laptop Whisper. 128 backend/466 Flutter/
  earlier 13 native tests, debug and signed release builds pass; real voice/accent/noise, microphone
  distance, TalkBack echo and latency acceptance remain open.
- **ISSUE-075 — Manual Smart AI transport/scope mismatch resolved by explicit
  owner approval.** The owner selected private-laptop Whisper with disclosure and
  deletion after processing on 2026-10-16. ADR-068's addendum and specification
  permit the existing paired manual path only. The screen now explains laptop
  processing/deletion before Speak; hands-free stays local and Gemini receives
  no audio. Phone cleanup and server success/failure/limit cleanup have automated
  evidence; physical cache/deletion acceptance remains open. The scope conflict
  is resolved; no broader transport or retention permission is implied.

Move the Pi and TECNO BG6 onto one non-isolated hotspot/private router, verify
the Pi's current address and TCP 8765, deploy/start the matching Module 65 Pi
service and updated Android app, then complete exclusive enrollment, Connect & Start, priority phone
audio, disconnect fallback, camera/NCNN and reconnect evidence. Continue the Module 55
Scanner voice/crash and TalkBack matrices afterward. Never close hardware
issues from simulator evidence.
