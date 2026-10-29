# Hotspot and phone speech verification — 2026-10-09

## 1. Module result

Module 65 software repairs are verified. 393 Flutter tests and 33 Pi tests pass;
Dart analysis and Ruff are clean; ARM64 debug/release APKs build. The updated
release is installed and running on the Medium Phone Android emulator.
**Physical Pi/hotspot/camera/phone-speaker acceptance remains open.** Only the
emulator is connected, and `rpi3-ml.local` is not resolvable from this Mac.
No universal error-free or real-world detection claim is made.

## 2. Workspace before implementation

76 existing modified/untracked status entries from earlier work were retained.
No commit, push, physical Pi deployment, password collection, system-clock
change, network scan or dependency upgrade was performed. Emulator installation
used `adb install -r` and succeeded without uninstalling app data in this module.

## 3–5. Architecture, state management and routing

Existing feature-first application/domain/infrastructure layers, Riverpod
state/dependency injection, centralized named routes, authenticated private-LAN
WebSocket v1 and one voice/TTS owner are retained. ADR-065 records the session,
canonicalization and feedback decisions. No route, cloud service or alternate
state framework was added. Pi camera frames remain local.

## 6–8. Structure, screens and domain types

No new folder or screen was needed. The existing Raspberry Pi screen gains
Test Phone Audio, an explicit muted-alert note, truthful search fallback copy,
and an enabled Disconnect control during pending startup/settings work.
No new domain entity type was created. `ProtocolEnvelope` retains exact encoded
timestamp text; the existing feedback interface adds test and stop operations.

## 9. Tests created/extended

New `raspberry_pi/tests/test_discovery.py` covers selected-interface ownership,
failed-registration cleanup and invalid advertisement addresses. Seventeen new
Flutter cases and seventeen new Pi cases extend the existing suites:

- Real Flutter sockets → Python simulated Pi: first enrollment/authentication,
  settings synchronization, Running, object/direction text through the wearable
  controller and phone-feedback adapter, heartbeat interleaving, reconnect,
  manual-address trust reuse, pause/resume/stop and revocation. Normal and
  ±365-day phone clocks all pass. Speech is recorded by a synthetic callback;
  it is not evidence of an audible physical phone speaker.
- Golden HMAC vectors preserve `.123000Z`/`.000000Z` text and small health values.
  A separate deterministic comparison matched 10,000 synthetic finite numbers
  between Python and the actual Dart JSON encoder, with zero differences.
- Phone audio test activation before enrollment, platform failure, accessible
  button naming/activation, cancellation during startup, and late speech failure.
- In-flight phone speech stops on pause/stop/background/disconnect. Shared voice
  tests prove Stop prevents delayed TTS after microphone pause and prevents a
  second recognition resume from an old utterance.
- Pi fallback cancels before phone ownership, mute and Stop. A failed persistent
  settings write leaves previous live settings intact; failed phone sync cannot
  trigger combined Start or overwrite the recovery message with success.

## 10–11. Markdown created/updated

Created: this report. Updated: CURRENT_MODULE.md, PROJECT_STATUS.md,
AGENT_HANDOFF.md, CHANGELOG.md, INDEX.md, KNOWN_ISSUES.md,
requirements-traceability.md, architecture.md, decision-log.md, TESTING.md,
PHONE_HOTSPOT.md, wearable-mode.md, wearable-protocol.md and
ui-accessibility-plan.md. A current wearable guide's stale hardcoded-IP claim
was corrected; historical records remain historical.

## 12. Requirements addressed

FR-008/010/011/012, NFR-ACC-001, NFR-SEC-002/004 and NFR-MAINT-002 gain software
verification evidence. Physical requirement statuses remain unchanged.

## 13–15. Commands, exact results and Android builds

Flutter commands run from `mobile_app/` unless noted. `PI_ENV` means
`AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python`
and `PYTHONPATH=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/src`.

| Command/check | Final result |
|---|---|
| Root `dart format --output=none --set-exit-if-changed mobile_app/lib mobile_app/test mobile_app/integration_test` | Exit 0; 233 files, 0 changed, 0.43 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; no issues found, 3.0 s |
| `PI_ENV flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; 393 passed, 0 failed/skipped, 12 s |
| `PI_ENV flutter --no-version-check test --no-pub test/features/wearable test/features/assistant/assistant_controller_test.dart -r expanded` | Exit 0; 79 passed before the final added startup-cancellation widget case; final full suite includes it |
| Root `PYTHONPATH=raspberry_pi/src raspberry_pi/.venv/bin/python -m pytest raspberry_pi/tests -o addopts= -q --disable-warnings` | Exit 0; 33 passed, 3.83 s |
| Root `laptop_backend/.venv/bin/ruff check raspberry_pi` | Exit 0; All checks passed |
| Root `laptop_backend/.venv/bin/ruff format --check raspberry_pi` | Exit 0; 27 files already formatted |
| Root `raspberry_pi/.venv/bin/python -m pip check` | Exit 0; No broken requirements found |
| Root `sh -n raspberry_pi/scripts/install.sh raspberry_pi/scripts/deploy.sh raspberry_pi/scripts/hotspot_network_dispatcher.sh` | Exit 0; no syntax errors |
| Deterministic numeric comparison using actual Dart encoder and Pi canonical serializer | Exit 0; 10,000 values, 0 mismatches |
| `flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi` | Exit 0; assembleDebug 10.4 s; ARM64 debug APK built |
| `flutter --no-version-check build apk --release --target-platform android-arm64` | Exit 0; assembleRelease 21.5 s; release APK built (178.3 MB) |
| Root Android SDK 36 `apksigner verify mobile_app/build/app/outputs/flutter-apk/app-release.apk` | Exit 0; signature verification passed |
| `adb devices -l` | Exit 0; emulator-5554 only, no physical handset |
| Bounded DNS/TCP check of documented `rpi3-ml.local:8765` | Exit 0; hostname not resolvable from this Mac; no hardware endpoint verified |
| `adb -s emulator-5554 install -r mobile_app/build/app/outputs/flutter-apk/app-release.apk` | Exit 0; Success |
| `adb -s emulator-5554 shell am start -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok, cold launch, MainActivity, TotalTime 7774 ms; process and foreground activity confirmed |
| Root `git diff --check` and SHA-256 comparison of tracked Stitch-related files against HEAD | Exit 0; no whitespace errors; 31 files, 0 changed/missing (20 original sources plus 10 renders and the audit document) |

Existing Kotlin-plugin future-migration warnings remain. Normal release build
regenerated production plugin metadata after debug; `--no-pub` was deliberately
not used for that release command. Aggregate native tests/lint were not rerun:
no native source changed, and their existing Maven dependency blockers remain
recorded in ISSUE-045/057 and the whole-project audit.

Artifacts:

- `mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`:
  780,532,209 bytes; SHA-256
  `34cea599c364a4a015f882ec2f94c2c822c3d22a849796845abbad185a3d58e2`.
- `mobile_app/build/app/outputs/flutter-apk/app-release.apk`:
  178,278,687 bytes; SHA-256
  `4883bc96d37cf61adc6bf253b1d1e80ea9088e91b22377c82205989355dc853b`.

### Reproduction and intermediate failures retained

The first expanded cross-stack run failed both cases: normal-clock sessions
reported heartbeat ordering failures; a one-year phone offset timed out during
enrollment. Both passed after one signing sequence and peer-time stamping.
Two new shared-voice tests then failed (resume count 2 instead of 1, and delayed
Chair speech after Stop); generation invalidation and pre-TTS checks repaired
both. A subsequent full run passed 387 and failed one cross-stack case because
a valid timestamp lost its trailing zeros and authentication rejection used an
unsupported client close code 1008. Exact timestamp preservation, compatible
canonical numbers and legal 4001/4003 client close codes fix these paths; final
393-test run passes. One analyzer unnecessary-cast warning was removed and
analysis rerun clean. An initial Pi run in the sandbox could not bind localhost;
rerun with authorized socket access in the dedicated Pi environment passes.
No failing test was deleted or skipped.

## 16–17. Files added and modified in this module

Added: this report and `raspberry_pi/tests/test_discovery.py`.
Existing files changed by this module (some already had preserved user edits):

```text
mobile_app/lib/app/wearable_controller.dart
mobile_app/lib/app/wearable_phone_feedback_service.dart
mobile_app/lib/app/wearable_providers.dart
mobile_app/lib/app/voice_kernel/vision_voice_kernel_v3.dart
mobile_app/lib/domain/services/wearable_phone_feedback_service.dart
mobile_app/lib/domain/entities/protocol_envelope.dart
mobile_app/lib/features/raspberry_pi/presentation/raspberry_pi_screen.dart
mobile_app/lib/infrastructure/networking/protocol_message_factory.dart
mobile_app/lib/infrastructure/networking/protocol_codec.dart
mobile_app/lib/infrastructure/networking/wearable_authenticator.dart
mobile_app/lib/infrastructure/networking/web_socket_wearable_repository.dart
mobile_app/lib/infrastructure/networking/web_socket_wearable_transport.dart
mobile_app/test/features/wearable/wearable_controller_accessibility_test.dart
mobile_app/test/features/wearable/wearable_simulator_e2e_test.dart
mobile_app/test/features/wearable/wearable_protocol_test.dart
mobile_app/test/features/wearable/wearable_transport_cancellation_test.dart
mobile_app/test/features/assistant/assistant_controller_test.dart
raspberry_pi/scripts/hotspot_network_dispatcher.sh
raspberry_pi/src/ai_blind_pi/discovery.py
raspberry_pi/src/ai_blind_pi/feedback.py
raspberry_pi/src/ai_blind_pi/service.py
raspberry_pi/src/ai_blind_pi/protocol.py
raspberry_pi/tests/test_engine_and_detector.py
raspberry_pi/tests/test_deployment_files.py
raspberry_pi/tests/test_protocol_security.py
```

The 14 existing documentation files are listed above. Generated APKs/build
metadata remain ignored. The repository-wide diff also contains earlier work;
its total must not be represented as this module's changes alone.

## 18–19. Deliberately unchanged and Stitch preservation

No native Android source, model/label assets, backend, SSH credential settings,
production signing, mobile/scanner implementation or Stitch source was changed
by this module. Existing edits to those areas were preserved. All 31 tracked
Stitch-related artifacts match HEAD; none is missing.

## 20–21. Known issues and deferred work

ISSUE-059..063 record repaired software paths; ISSUE-064 records the stale guide
conflict. The development Pi environment now passes its own tests/pip check
(ISSUE-042). Physical hotspot NSD/TCP behavior, first enrollment, actual phone
speaker/Pi silence, disconnect fallback, camera/NCNN, TalkBack, DHCP restart and
sustained latency/thermal remain unverified (ISSUE-028/046/048/050 and existing
hardware issues). Trusted-LAN TOFU and non-confidential ws:// remain the accepted
existing boundary; no port forwarding or cloud frame processing was introduced.
Release signing/icon, unrelated Scanner debt, and aggregate native/lint Maven
blockers remain deferred. No additional feature scope was invented.

## 22. Exact next action

Power on the physical Pi, enable the target phone's 2.4 GHz owner hotspot, join
the Pi once per PHONE_HOTSPOT.md, and provide its current reachable hostname/IP.
Deploy the matching updated Pi service with the existing deploy/install scripts
and update the target phone. Run TESTING.md's Module 65 matrix: Test Phone Audio,
Connect & Start, safe stationary objects spoken by the phone, Pi silence,
pause/stop, changed DHCP/reconnect, disconnect fallback and TalkBack. Record
actual observations before closing hardware gates. Simulator evidence does not
replace these checks.

## 23. Git-style summary

```text
fix(wearable): align authenticated session clock, sequence and HMAC encoding
fix(feedback): cancel stale speech and persist settings before applying
feat(wearable): add accessible phone audio test and available disconnect
fix(pi): scope mDNS and schedule hotspot service restart without blocking
test: add 34 regression cases across Flutter and Pi
docs: record verified software evidence and physical acceptance gates
```

No commit or push was performed.
