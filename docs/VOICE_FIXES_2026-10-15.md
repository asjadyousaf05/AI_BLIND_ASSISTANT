# Scanner, Smart AI connection and voice-session verification

Date: 2026-10-15. Module 66. The owner reported three real-phone usability
issues, then selected **release APK installation on the emulator only** for
this repair. No physical speech/Scanner acceptance is claimed by this report.

## Resulting behavior

- **Scanner:** “restart scanner”, “restart the scanner”, “scan again” and
  explicit rescan variants request a fresh capture. The existing Scanner
  workflow stops old reading, initializes/waits for the camera, captures,
  performs local OCR, deletes its temporary photo and reads the new page.
  The command returns no competing TTS utterance. Duplicate pending captures
  are suppressed. Touch Scan Another Document still returns to framing;
  Restart Reading still selects the first reading unit.
- **Smart AI:** opening the screen or returning from Connection settings checks
  the saved paired laptop's health/version. Credential loading is shared;
  overlapping checks share one operation; the health request has an eight-second
  bound. Pairing changes/disposal reject late results. Reachability has separate
  state, so local app controls remain usable. Retry checks connectivity without
  replaying a question. Opening/retrying an OCR draft does not submit its text.
  An unpaired installation still requires the owner's explicit one-time pairing.
  Health is not proof that authentication or an AI provider will accept a query.
- **Exit:** complete explicit phrases such as “goodbye”, “stop listening”,
  “end voice session” and “exit Smart AI” are required. Bare bye/by/buy,
  homophone transcripts and incidental substrings do not dismiss the session.
  Exact exits take priority over Mobile Mode's semantic Stop interpretation.
  Native focused grammars and backend deterministic matching agree. Exiting
  Smart AI returns to offline commands; offline goodbye restores wake-only mode.

## Exact final verification

Commands run from `mobile_app/` unless a different location is given.
`PI_ENV` means
`AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python`
and `PYTHONPATH=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/src`.

| Command/check | Result |
|---|---|
| `flutter --no-version-check pub get --offline` | Exit 0; cached camera_platform_interface 2.13.1 promoted from transitive to direct dev dependency; no runtime package upgraded |
| `dart format lib test integration_test` | Exit 0; 235 files; final formatting check below changed none |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 235 files, 0 changes |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, final run 3.5 s |
| `flutter --no-version-check test --no-pub --timeout 30s test/features/ocr_scanner/scanner_voice_rescan_test.dart -r expanded` | Exit 0; 2 passed after fixture corrections; final full suite also includes them |
| `PI_ENV flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **404 passed, 0 failed/skipped**, 13 s; actual Python Pi simulator enabled |
| Root: `laptop_backend/.venv/bin/python -m pytest laptop_backend/tests/unit/test_local_commands.py -q -o addopts=` | Exit 0; 49 passed, 1 upstream warning, 0.03 s |
| Root: `laptop_backend/.venv/bin/python -m pytest laptop_backend/tests -q -o addopts=` | Exit 0; **108 passed**, 32 upstream deprecation warnings, 0.94 s |
| Root: `laptop_backend/.venv/bin/ruff check laptop_backend/src laptop_backend/tests` | Exit 0; All checks passed |
| Root: `laptop_backend/.venv/bin/ruff format --check laptop_backend/src/ai_assistant/tools/local_commands.py laptop_backend/tests/unit/test_local_commands.py` | Exit 0; 2 files already formatted |
| From `mobile_app/android/`: `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain` | Exit 0; BUILD SUCCESSFUL in 13 s; fresh XML: **9 tests**, 0 failures/errors/skips |
| `flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi` | Exit 0; assembleDebug 11.9 s; debug APK built for verification |
| `flutter --no-version-check build apk --release --split-per-abi --target-platform android-arm64` | Exit 0; assembleRelease 27.9 s; signed release APK built; production plugin preparation ran without --no-pub |
| SDK 36 `apksigner verify --verbose --print-certs <release-apk>` | Exit 0; one project release signer; v2 signature valid |
| SDK 36 `zipalign -c -P 16 4 <release-apk>` | Exit 0; alignment valid |
| SDK 36 `aapt dump badging <release-apk>` and ZIP inspection | Exit 0; 1.4.3/code 4043; ARM64; min SDK 24/target 36; no debuggable flag; libapp.so present; no debug kernel blob |
| `adb -s emulator-5554 install --no-incremental -r mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | Exit 0; Performing Streamed Install; Success |
| Emulator package query and installed base-APK SHA-256 | Exit 0; version 1.4.3/code 4043; DEBUGGABLE absent; installed checksum equals the artifact below |
| `adb -s emulator-5554 shell am start -S -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok; initial launch opened foreground microphone permission (1517 ms, not app-only latency) |
| Same cold-launch command after settling permission | Exit 0; Status ok; LaunchState COLD; MainActivity; TotalTime 930 ms / WaitTime 942 ms; resumed app and live process confirmed; current process crash buffer has 0 fatal markers |
| Emulator native UI actions | Foreground-only microphone allowed; Continue → Home → Assistant passed; Smart AI title and explicit first-pairing guidance visible; app resumed. No question or document submitted |
| Existing `com.ai-blind-assistant.backend` launch service restart | `launchctl kickstart -k gui/<uid>/com.ai-blind-assistant.backend` exit 0; first short health polling window expired; later /health returned status ok/protocol v1 with a running launch-service process |
| Preservation, links and whitespace checks | Exactly 28 intended existing files changed (14 code/test/config, 14 Markdown); 3 new files; no unexpected changes or missing pre-existing files; 31 Stitch files unchanged; 66 local Markdown links resolve; git diff --check exit 0 |

The full Pi Python suite, aggregate native plugin tests and complete Android
lint were not rerun: no Pi code changed, and existing native/lint dependency
blockers remain ISSUE-045/057. Nine app-native tests are not the aggregate
plugin suite. Existing Kotlin/Gradle migration warnings remain; neither Android
build failed. No new physical accuracy, voice-noise or performance result exists.

## Runtime follow-up: complete app launch

The owner subsequently requested “run app completly”. The existing release APK
was launched on emulator-5554 without a Flutter debug session. The backend's
`/health` returned status ok/protocol 1 with Ollama available, `llama3.2:3b`
selected and Gemini not configured; Ollama's `/api/tags` also responded.

The backend had no active device pairing before this run. Its existing
`PYTHONPATH=src .venv/bin/python scripts/create_pairing_code.py` owner workflow
generated a short-lived code, captured only in memory and entered in the
emulator Connection form using `10.0.2.2:8765`. No credential was printed.
The first UI assertion missed the success label after the paired form changed
height; read-only backend credential presence and returning to Smart AI then
confirmed pairing and reachable status. No second code or auth bypass was used.

An explicitly submitted synthetic text request, “Reply with the single word
ready.”, received “ready” through the app/backend/local Ollama path. No request
was pending and no request error was visible. This proves that one emulator
typed conversation completed; it does not establish physical voice, camera,
OCR, Pi or provider-outage acceptance. The release app and local services remain
running. No source, APK, signing configuration or phone installation changed;
test suites/builds were not rerun for this runtime-only follow-up.

## Later authorized wireless phone installation

The owner subsequently requested deployment to `192.168.10.36:36063` and
supplied temporary pairing details. Some supplied pairing ports were closed
and discovery showed changing ports; attempts returned protocol-status-read
faults. Pairing finally succeeded with the current open dialog, followed by
successful ADB connection. No temporary code or phone identifier is retained
in this report. This is a TECNO LE6, distinct from the earlier TECNO BG6 in
ISSUE-070: Android 11/API 30, ARM64, with no existing application package.

| Command/check | Observed result |
|---|---|
| `adb pair <current-pairing-endpoint> <temporary-code>` | Exit 0; Successfully paired; code/device identifier omitted |
| `adb connect 192.168.10.36:36063` | Connected |
| Release hash, `apksigner verify --verbose --print-certs`, `aapt dump badging` | Existing verified hash; valid v2 project-release signature; 1.4.3/code 4043, ARM64, min SDK 24/target 36, no debuggable flag |
| `adb -s 192.168.10.36:36063 install --no-incremental -r mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | Exit 0; Performing Streamed Install; Success |
| Installed package metadata and `sha256sum <installed-base.apk>` | 1.4.3/code 4043, DEBUGGABLE absent; SHA-256 matches the release below |
| `adb -s 192.168.10.36:36063 shell am start -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok; COLD MainActivity; TotalTime 5599 ms / WaitTime 5621 ms |
| Post-launch process/activity/UI and PID-scoped crash-buffer check | App alive/resumed, welcome Continue visible, no permission dialog, zero current-process fatal markers |

The app is left at welcome Continue. Permissions remain under the user's
control; no laptop pairing, conversation/document submission or physical
Scanner/voice acceptance was performed. No uninstall/data-clear, re-sign,
application source change or rebuild was needed. Tests were not rerun for this
installation; the earlier software evidence keeps its recorded scope.

## Release identity

| Property | Value |
|---|---|
| APK | `mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Mode | Flutter release/AOT; non-debuggable |
| Package | `com.example.ai_blind_assistant` |
| Version | `1.4.3+2043`; ARM64 split versionCode `4043` |
| Bytes | 125,916,832 |
| SHA-256 | `66c0bc9e518ccde3b127c4c4f47abaa768a7776a98525d34bb679aee427a93eb` |
| Public signer SHA-256 | `f98b86d6b1fda2b9229b1960603178e11fb91c109d6ab457cc55d291c05f33f8` |
| Target | ARM64 emulator-5554; later authorized TECNO LE6/API 30 wireless installation |

The immutable `deliverables/AI-Blind-Assistant.apk` and its older checksum were
not replaced. Release keys/configuration were not changed. An emulator release
install does not prove physical camera, TalkBack, voice recognition or latency.

## Intermediate failures and corrections

The initial targeted run exposed that “stop listening” in Mobile context was
resolved as StopMobileDetection before reaching conversation patterns. Exact
explicit dismissal now resolves before semantic matching; all-context tests pass.

The new synthetic Scanner fixture initially stalled on temporary-directory IO
inside Flutter's fake-async test zone. Later fixed-delay and real-loop-only
attempts did not reliably advance both widget callbacks and file operations;
one full run had 402 passes and two fixture failures. The final fixture drives
both loops until capture/reading completion with a bounded wait. Both tests
pass alone and in the final 404-test suite. No failing test was removed.

One automatic permission-review request timed out before starting a test
command; the permitted retry succeeded. This was not a test result or evidence
that the command was unsafe. The backend's initial health polling window after
restart also expired; subsequent health verification passed. Neither failure
is hidden or counted as an initial pass.

## Earlier phone-installation context

Before the owner redirected this repair to the emulator, the earlier 1.4.2
phone update encountered a release/development signing mismatch. Android rejected
the project release signer; the installed public certificate matched the existing
development key. A separate release-mode compatibility APK was signed with that
key. Incremental ADB reported Success but then no package was queryable. A full
`--no-incremental -r` install recovered the package, and its SHA-256 and cold
launch were verified. No uninstall or data-clear command was run. Android's
first-install timestamp changed during recovery, so **old phone settings/pairing
retention is unverified**. ISSUE-070 records this; do not claim preservation.
The later phone connection went offline; no Module 66 phone update was attempted
after the owner's emulator-only instruction.

## Required completion record

| Item | Report |
|---|---|
| 1. Module result | Three software repairs verified; signed release installed on emulator; physical acceptance open |
| 2. Workspace before implementation | 97 existing Git status entries; source/docs already edited by earlier work; a 474-file hash snapshot saved for preservation checks |
| 3. Architecture | Existing feature-first presentation/application/domain/infrastructure layers retained; ADR-066 records behavior |
| 4. State management | Riverpod; backend reachability independent of voice session state |
| 5. Routing | Existing centralized named routes and route observer retained |
| 6. Folder structure created | None; existing directories reused |
| 7. Screens created | None; existing Assistant screen refined; Scanner widget preserved |
| 8. Domain types created | AssistantBackendStatus enum |
| 9. Tests created | New synthetic Scanner widget test file (2 tests); existing domain/controller/screen/native/backend tests extended |
| 10. Markdown files created | VOICE_FIXES_2026-10-15.md |
| 11. Markdown files updated | CURRENT_MODULE, PROJECT_STATUS, AGENT_HANDOFF, CHANGELOG, INDEX, KNOWN_ISSUES, TESTING, architecture, decision-log, requirements-traceability, BUILD_AND_RUN, OFFLINE_VISION_ASSISTANT_GUIDE, DOCUMENT_SCANNER_GUIDE, assistant |
| 12. Requirements addressed | FR-001/013/015/019/021/022; NFR-OFFLINE-002, NFR-REL-001, NFR-SEC-003, NFR-MAINT-002 |
| 13. Commands executed | Exact verification and deployment commands in the table above |
| 14. Exact command results | 404 Flutter / 108 backend / 9 native passes; static/format checks clean; intermediate failures retained above |
| 15. Android build result | Debug and release ARM64 builds passed; only release installed on emulator |
| 16. Files added | This report; mobile_app/lib/domain/enums/assistant_backend_status.dart; mobile_app/test/features/ocr_scanner/scanner_voice_rescan_test.dart |
| 17. Files modified | 14 existing code/test/config files listed below, plus the 14 living Markdown documents above |
| 18. Deliberately unchanged | Pi source, model assets, Scanner widget, routing, signing configuration/keys, immutable APK deliverables, presentation brief/Word copy and unrelated pre-existing edits |
| 19. Stitch preserved | All 31 tracked Stitch-related files present and unchanged |
| 20. Known issues | ISSUE-067/068/069 repaired in software; physical checks open; ISSUE-070 phone data retention unverified; existing native/lint/camera-layering gates retained |
| 21. Deferred work | Physical voice/Scanner/TalkBack/Pi acceptance; paired live conversation; hardware performance; aggregate native/lint dependencies |
| 22. Exact next action | Pair the optional laptop once in emulator Connection settings if conversation is desired; execute Module 66's physical TESTING.md matrix when authorized |
| 23. Git-style summary | fix(voice): rescan pages, connect Smart AI on entry, require explicit exits; no commit/push |

Existing code/test/config files modified by this repair:

```text
laptop_backend/src/ai_assistant/tools/local_commands.py
laptop_backend/tests/unit/test_local_commands.py
mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiSpeechGrammar.kt
mobile_app/android/app/src/test/kotlin/com/example/ai_blind_assistant/VisionAiWakePhraseTest.kt
mobile_app/lib/app/assistant_session_controller.dart
mobile_app/lib/app/voice_kernel/command_executor.dart
mobile_app/lib/domain/services/intelligent_intent_resolver.dart
mobile_app/lib/domain/services/voice_action_registry.dart
mobile_app/lib/features/assistant/presentation/assistant_screen.dart
mobile_app/pubspec.yaml
mobile_app/pubspec.lock
mobile_app/test/domain/intent_resolver_test.dart
mobile_app/test/features/assistant/assistant_controller_test.dart
mobile_app/test/features/assistant/assistant_screen_test.dart
```
