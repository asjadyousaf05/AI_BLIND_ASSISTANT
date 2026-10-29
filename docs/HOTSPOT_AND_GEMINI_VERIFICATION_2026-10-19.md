# Phone hotspot and personal Gemini verification

Date: 2026-10-19 (Asia/Karachi). Module 69. Integration verified; owner rejects detection speed.

## Implemented behavior

The phone hosts one Personal Hotspot. Laptop and Pi join as clients; concurrent
station Wi-Fi is not required. Pi detection and laptop Whisper/Ollama use their
own current DHCP endpoints. USB debugging is for installation and diagnosis.
No supplied login or hotspot password is retained in source or this report.

Connect Assistant now restores its saved laptop endpoint and explains hotspot
addresses instead of selecting an old university-network IP. Optional direct
Gemini uses an owner-entered personal key, explicit disclosure/agreement,
separate Keystore encryption, a fixed HTTPS endpoint, a header key, `store:false`,
bounded text/history/response/time, no redirects/retries and no tool execution.
Direct mode uses phone-local speech and TTS with no laptop health/pairing call.
Removing its key preserves Pi/laptop trust and clears conversation memory.

## Commands and exact software results

Commands run at repository root unless the working directory is stated.

| Command | Result |
|---|---|
| `dart format` on changed source/test files, including startup and speech follow-ups | Exit 0; final pass changed 0 files |
| `flutter --no-version-check analyze --no-pub` in `mobile_app/` | Exit 0; No issues found |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded` in `mobile_app/` | Exit 0; 498 passed; real Python Pi simulator enabled; no skips/failures |
| `raspberry_pi/.venv/bin/python -m pytest -o addopts='' raspberry_pi/tests -q --disable-warnings` | Exit 0; final 38 passed in 2.84 s; initial integration had 33 |
| `laptop_backend/.venv/bin/python -m pytest laptop_backend/tests -q --disable-warnings` | Exit 0; 128 passed, 35 warnings in 1.52 s |
| `laptop_backend/.venv/bin/ruff check raspberry_pi/src raspberry_pi/tests laptop_backend/src laptop_backend/tests` | Exit 0; All checks passed |
| `sh -n raspberry_pi/scripts/install.sh raspberry_pi/scripts/hotspot_network_dispatcher.sh raspberry_pi/scripts/deploy.sh` | Exit 0 |
| `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain` in `mobile_app/android/` | Exit 0; BUILD SUCCESSFUL in 7 s; XML totals 13 tests, zero failures/errors/skips |
| ARM64 split debug build, build name 1.4.7/build number 2047 | Exit 0; final assembleDebug 9.7 s (earlier 9.2/25.6 s) |
| ARM64 split release build with `--no-pub` | Exit 1; known stale `GeneratedPluginRegistrant` reference to unavailable `integration_test` release package; no test removed |
| Same release build with normal dependency/plugin preparation | Exit 0; final assembleRelease 22.7 s (earlier 21.8/30.5 s); ARM64 APK 126.0 MB |
| `flutter --no-version-check test --no-pub test/features/assistant -r expanded` | Exit 0; 118 passed after final mode-specific history-clear disclosure; clean analysis/formatting |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub test/features/wearable/wearable_simulator_e2e_test.dart -r expanded` | Exit 0; final three real Flutter/Python cases pass, including ±365-day clock offsets |
| `laptop_backend/.venv/bin/ruff format --check raspberry_pi/src raspberry_pi/tests` | Exit 0; 24 files already formatted |
| `git diff --check` | Exit 0 |

Final build commands in `mobile_app/`:

```sh
flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi --build-name=1.4.7 --build-number=2047
flutter --no-version-check build apk --release --target-platform android-arm64 --split-per-abi --build-name=1.4.7 --build-number=2047
```

Earlier new-fixture failures were corrected: tests now inject Gemini storage
instead of waiting on a nonexistent native test channel. The consent widget
test pumps after changing the checkbox before activating its enabled button.
All corresponding original assertions remain and pass.
The timing follow-up initially added extra health fields; the strict v1 client
correctly rejected them in three cross-stack cases. Removed those wire additions
and retained timing locally. Final cross-stack cases pass; no schema relaxation
or assertion deletion was used.

## Physical setup evidence

- USB-connected TECNO BG6, Android API 33. Its hotspot is active; phone local
  address `192.168.79.20`, laptop `192.168.79.21`, Pi `192.168.79.190`.
  These are observations, not static defaults.
- Laptop `/health` responds ok/protocol 1 at localhost and the hotspot address;
  Ollama `llama3.2:3b` is available and Gemini is not configured on the laptop.
- `rpi3-ml.local` resolves; TCP 22 is reachable. The owner separately verified
  the changed ED25519 fingerprint before only that hostname's saved SSH key was
  replaced. Normal host verification remains enabled. Supplied login was used
  interactively without storing the password.
- Fresh Pi OS: aarch64, Python 3.13.5, OV5647 detected by
  `rpicam-hello --list-cameras`; no prior service/model/NCNN existed, so TCP 8765
  initially refused the connection.
- Finalized NCNN artifacts found externally on the development machine match
  all three existing `raspberry_pi/model/SHA256SUMS` entries. Deployment archives
  exclude development virtual environments, caches and runtime state.
- Installed Pi OS packages: python3-venv/avahi already present; espeak-ng and its
  four dependencies installed successfully. No OS upgrade, training runtime,
  camera-frame capture file or cloud vision service was introduced.
- Existing installer completed with `--bind-host auto`, explicit verified model
  source and `--start`. Runtime installed official `ncnn==1.0.20260526`,
  websockets 15.0.1, zeroconf 0.151.5 and dependencies. Service is enabled on boot,
  active/running with zero restarts, listening on `192.168.79.190:8765`.
- Real `validate-model` succeeds: NCNN `in0`/`out0`, 320×320 input, actual
  `[605,2100]` output, 601 indexed Open Images V7 labels. Model content is not
  replaced or retrained.
- Phone update: release-mode 1.4.7/code 4047 signed with the existing phone's
  development certificate, distinct from the retained project release artifact.
  `adb install --no-incremental -r` succeeds. Installed hash matches the candidate;
  DEBUGGABLE absent and first-install time remains 2026-10-15 07:27:09. No uninstall,
  data clear or signing-source edit. Cold launch returns Status ok, final cold launch TotalTime 1341 ms / WaitTime 1389 ms; zero current-process fatal markers.

Physical app result: one tap on Connect & Start discovered `rpi3-ml`, completed
exclusive enrollment, authenticated, synchronized settings and entered Wearable
assistance running. Pi `ss` confirms the peer is the hotspot-host phone at
`192.168.79.20`, with no USB reverse tunnel or laptop relay. Audio Alerts are on;
confidence 45%, cooldown five seconds and synchronization acknowledged. The
owner explicitly confirms hearing Test Phone Audio clearly.

The first audible test nevertheless displayed a TTS warning. Its previous
67-character feedback deadline was only about 5.4 seconds. Increased the normal
speech budget to 180 ms/character, at least five seconds and at most two minutes;
Stop/replacement cancellation remains immediate and reader-sentence behavior is
unchanged. Added synthetic-clock regressions for successful eight-second speech
and bounded missing-completion failure. Final on-phone repeat now displays Audio test finished without the warning.

After installing the final speech update, the Pi remained active while the
phone app was replaced. Reopening Wearable Mode and tapping Connect & Start
reused saved trust and restored Running. No credential reset or new enrollment
was necessary. Both final builds and the full 498-test suite pass.

Final artifact identities:

- Project-signed ARM64 release: 125,982,448 bytes, SHA-256
  `462addf4e9cc0d5811a3ca7180ca556585d96ff58aee251587ad3e13286331e1`.
- Installed matching-development-certificate release-mode candidate:
  126,027,687 bytes, SHA-256
  `12d7824be3f0d94872a56ca6689c4d119b4cab0102d5fc26239f657bec38f30f`.
  Installed bytes verified by pulling the actual base APK. Identical deliverable:
  `deliverables/AI-Blind-Assistant-1.4.7-hotspot.apk`.

Physical health: camera Active, model Ready, live classification telemetry,
52–53 °C and 57–59% memory observed. `vcgencmd get_throttled=0x50005` confirms
current under-voltage and throttling, not just history. The owner confirms
power is supplied by a laptop USB port. Stable model-appropriate supply/cable
is required before sustained performance can be accepted. Do not change power
by abruptly disconnecting a running Pi.

Final speech completion is verified on the phone: Audio test finished, no
warning. The owner confirms clear test sound. The owner also confirms real detections produce phone audio, but reports
slow detection and inadequate perceived quality. Speed investigation is active;
this report does not accept detection performance. Configuration
without an owner Gemini key cannot verify live API access, quotas or response
quality. The personal key should be entered on the phone, never pasted into chat.

## Detection-speed follow-up and deployed model

The owner confirms moving power from laptop USB to a 5 V/2 A adapter. The Pi
rebooted during an earlier camera benchmark; that interrupted run provides no
comparison. After boot, the enabled service and saved phone trust recovered.
History-only `0x50000` was briefly observed idle; under load it returns to active
`0x50005`, with actual CPU about 600 MHz against requested 1.2 GHz. Power is not
accepted. Official Pi 3 guidance recommends 5 V/2.5 A at the connector; cable
voltage loss matters. Clean shutdown is required before changing the supply.

Synthetic unchanged-model runs with three samples per thread count measured
approximately 922/634/575/515 ms for 1/2/3/4 NCNN threads under throttling.
The completed real-camera benchmark uses eight frames per profile and retains
only aggregate durations; no frames or object content are saved:

| Profile | Mean capture | Mean detection | Maximum detection | Actual CPU / power |
|---|---:|---:|---:|---|
| 640×480, 12 camera FPS, three threads | 175.0 ms | 584.8 ms | 611.8 ms | 600 MHz / 0x50005 |
| 320×240, eight camera FPS, four threads | 227.5 ms | 544.5 ms | 629.0 ms | 600 MHz / 0x50005 |

Mean inference improves about 7% in this short test, but capture takes longer;
no end-to-end latency or accuracy gain is established. Camera FPS is not model
inference FPS. Deployed the smaller ISP capture, four NCNN threads and frame
stride one, preserving model/tensor/confidence/two-frame stability, cooldown
and rate limits. A single-slot newest-frame buffer was already present.
The root-only backup preserves the previous profile/source; reinstalling the
service wheel used `--no-deps`, preserving installed dependencies and pairing.
Deployed source and installed service hashes match the workspace.

Local aggregate logs after 30–810 processed frames record sampled inference
520–556 ms, frame age 583–616 ms and zero buffer drops. These are selected
30-frame interval observations, not percentiles or a complete distribution.
The service stays active with zero automatic restarts in this session. This
short run does not establish sustained thermal/performance acceptance.
The owner explicitly reports **still too slow** after this deployment.

Current power health now reads bits 0–3, without treating historical bits
16–19 as active; five regression vectors pass. Timing is local/log-only;
strict protocol-v1 health stays unchanged. No clock override, undervoltage
suppression, camera upload, cloud vision, frame retention or model replacement.

The deployed Pi metadata was read directly under the service identity:

- Ultralytics **YOLOv8n (Nano)**; description says trained on
  `open-images-v7.yaml`; **Google Open Images V7**, **601 indexed classes**.
- NCNN **FP32**, input **320×320**, exporter **8.4.106**, actual output `[605,2100]`.
- All three artifacts match the existing [model checksum manifest](../raspberry_pi/model/SHA256SUMS).
- This verifies artifact identity/metadata, not an independent audit of its
  training. No custom household fine-tuning lineage or held-out accuracy is
  established (ISSUE-065). Phone Mobile Mode uses its own separate model.

## Final phone/laptop and app follow-up

Generated an owner code locally and entered it directly into the phone without
printing/saving it. Phone shows Paired/protocol v1 at the laptop hotspot endpoint.
After the final in-place update, Smart AI reports Laptop assistant is reachable
and a real synthetic typed request receives `Ready.` from local Ollama. This
verifies phone-to-laptop use of the hotspot, without a USB reverse tunnel.
The currently configured phone pairing replaces the backend's prior single-user
phone credential; that is the existing exclusive pairing behavior.

Final app-only follow-up makes history-clear confirmation match direct Gemini's
phone-memory scope. 118 assistant cases and clean analysis/format pass; both
builds were repeated and the final installed bytes/signature/non-debuggable
flags/first-install time/cold launch were checked again. Returned the phone to
Wearable Mode, confirmed its restored Pi trust and activated Connect & Start.
The phone subsequently locked; final post-lock authentication/audio was not
reverified and the Pi later showed no phone socket. Earlier actual object audio,
saved-trust reconnection and Running evidence remains as recorded above. No
Gemini key was entered, so no live provider request or free-quota access is claimed.

## Provider sources checked

- [Google API pricing](https://ai.google.dev/gemini-api/docs/pricing): the selected
  Flash-Lite model lists free input/output access; availability is quota-limited.
- [Rate limits](https://ai.google.dev/gemini-api/docs/rate-limits): consult the
  owner's actual AI Studio project; no fixed requests-per-day promise is made.
- [API key guidance](https://ai.google.dev/gemini-api/docs/api-key): no shared key
  in a client binary; personal user-entered operation is a scoped prototype
  exception. Shared production keys require a backend proxy.
- [Gemini terms](https://ai.google.dev/gemini-api/terms): unpaid-service content
  use is disclosed; `store:false` does not promise exemption from provider terms.
- [Interactions](https://ai.google.dev/gemini-api/docs/interactions-overview):
  fixed endpoint, stateless storage setting and supported model IDs.
- [Android concurrency](https://source.android.com/docs/core/connect/wifi-sta-ap-concurrency):
  simultaneous station/hotspot support varies; this topology uses hotspot only.

## Completion record

1. **Module result:** requested software and physical hotspot integration delivered;
   sustained performance, full physical matrix and live Gemini remain gated.
2. **Initial workspace:** many pre-existing modified/untracked files; all preserved.
   A hash snapshot of 527 existing project files preceded this work.
3. **Architecture:** existing feature-first presentation/application/domain/
   infrastructure layers; two injected Gemini interfaces and adapters.
4. **State management:** existing Riverpod Notifier/providers.
5. **Routing:** existing centralized named AppRoute/RoutePaths; no new route.
6. **Folders:** production structure reused; `mobile_app/test/helpers/` added.
7. **Screens:** existing Assistant, Connection, Settings and Startup refined;
   one embedded `GeminiConnectionCard`, no new full screen.
8. **Domain types:** `GeminiConfiguration`, configuration repository and text
   conversation service interfaces, safe Gemini conversation exception.
9. **Tests:** four new Gemini test files, shared fakes and two existing-file TTS
   regressions: 32 additional cases in the full 498-test Flutter suite. Five new
   Pi power vectors bring its suite to 38; three cross-stack cases pass again.
10. **Markdown created:** this verification report.
11. **Markdown updated:** agent guide, active module/status/handoff/changelog,
    index, testing, known issues, specification, traceability, architecture,
    decision log, assistant, hotspot, build/run and deliverables guidance.
12. **Requirements:** FR-008/010/011/012/013/019/021/022,
    NFR-OFFLINE-001/002, NFR-REL-001, NFR-SEC-002/003/004,
    NFR-MAINT-001/002, BR-003; evidence bounded by the physical gates above.
13. **Commands:** formatting/analyze/Flutter/backend/Pi/native tests, both
    builds, signer/hash/package/install/launch checks, verified SSH, Pi OS
    dependency installation, existing Pi installer, camera/model/socket/health
    probes and whitespace/Stitch checks, as recorded above.
14. **Exact results:** all final software checks pass; fixture/plugin-registrant/
    strict-schema failures and corrections are retained above. Owner rejects
    physical detection speed. No test was deleted.
15. **Android:** final debug 9.7 s and release 22.7 s pass; matching-signer
    release-mode phone update succeeds without uninstall/data clear.
16. **Files added:** listed below; ignored delivery APK is additional.
17. **Files modified:** listed below relative to the initial hash snapshot,
    rather than attributing earlier uncommitted work to this module.
18. **Deliberately unchanged:** original unrelated edits, model binaries,
    Android native source, route definitions, dependencies,
    source version/signing files and earlier deliverable APK.
19. **Stitch:** all 31 related tracked files exist and match initial SHA-256.
20. **Known issues:** current Pi under-voltage/throttling persists on the 2 A
    adapter; owner rejects speed. Custom model training lineage and remaining
    physical/provider acceptance are open. False audio warning is fixed.
21. **Deferred:** power-restored sustained performance, full hotspot/DHCP/reboot/
    WAN-off/TalkBack and Pi-speaker fallback, live Gemini access and quality;
    broader existing FYP acceptance gates remain in KNOWN_ISSUES.
22. **Exact next action:** clean shutdown before changing to a stable Pi 3
    supply/cable, then verify current voltage/actual clock under load and repeat
    owner object speed/quality acceptance. Execute remaining recovery/offline
    matrix. Enter a personal Gemini key on the phone after disclosure for live
    laptop-free verification. Obtain custom checkpoint/training/evaluation
    artifacts before attributing deployment to household fine-tuning.
23. **Git-style summary:** `feat(assistant): personal Gemini and verified phone-hotspot Pi setup`.
    No commit or push performed.

### Added source/test/report files

```text
docs/HOTSPOT_AND_GEMINI_VERIFICATION_2026-10-19.md
mobile_app/lib/domain/entities/gemini_configuration.dart
mobile_app/lib/domain/repositories/gemini_configuration_repository.dart
mobile_app/lib/domain/services/gemini_conversation_service.dart
mobile_app/lib/features/assistant/presentation/gemini_connection_card.dart
mobile_app/lib/infrastructure/assistant/http_gemini_conversation_service.dart
mobile_app/lib/infrastructure/assistant/secure_gemini_configuration_repository.dart
mobile_app/test/features/assistant/direct_gemini_controller_test.dart
mobile_app/test/features/assistant/gemini_connection_screen_test.dart
mobile_app/test/features/assistant/http_gemini_conversation_service_test.dart
mobile_app/test/features/assistant/secure_gemini_configuration_repository_test.dart
mobile_app/test/helpers/gemini_fakes.dart
```

Additional ignored deliverable: `deliverables/AI-Blind-Assistant-1.4.7-hotspot.apk`.

### Existing files modified by this task

```text
AGENTS.md
deliverables/README.md
docs/AGENT_HANDOFF.md
docs/BUILD_AND_RUN.md
docs/CHANGELOG.md
docs/CURRENT_MODULE.md
docs/INDEX.md
docs/KNOWN_ISSUES.md
docs/PHONE_HOTSPOT.md
docs/PROJECT_STATUS.md
docs/TESTING.md
docs/architecture.md
docs/assistant.md
docs/decision-log.md
docs/requirements-traceability.md
docs/specification-baseline.md
mobile_app/lib/app/assistant_providers.dart
mobile_app/lib/app/assistant_session_controller.dart
mobile_app/lib/app/voice_kernel/command_executor.dart
mobile_app/lib/core/constants/assistant_defaults.dart
mobile_app/lib/features/assistant/presentation/assistant_connection_screen.dart
mobile_app/lib/features/assistant/presentation/assistant_screen.dart
mobile_app/lib/features/assistant/presentation/assistant_settings_screen.dart
mobile_app/lib/features/startup/presentation/startup_screen.dart
mobile_app/lib/infrastructure/assistant/flutter_tts_speech_output_service.dart
mobile_app/test/features/assistant/assistant_controller_test.dart
mobile_app/test/features/assistant/assistant_screen_test.dart
mobile_app/test/features/wearable/wearable_phone_tts_test.dart
raspberry_pi/config/wearable.env.example
raspberry_pi/src/ai_blind_pi/config.py
raspberry_pi/src/ai_blind_pi/service.py
raspberry_pi/tests/test_engine_and_detector.py
```
