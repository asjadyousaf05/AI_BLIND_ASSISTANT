# Whole-project audit — 2026-10-09

## Result and limits

The available automated checks were exercised across Flutter, the laptop
backend, Raspberry Pi simulation, Android application code, packaged models,
configuration and deployment helpers. Reproduced defects were repaired and
regression tests added. This is software verification, not acceptance of every
possible case. No Android device was attached. Physical camera/OCR, microphone,
TalkBack, TTS/haptics, Pi deployment/network/audio, battery accuracy and sustained
performance remain open. No feature or hardware gate is declared universally
complete.

The workspace started with 57 status entries from existing work, including
untracked tests and documentation. Those changes were retained. No commit,
push, device install, Pi deployment, dependency upgrade or service configuration
change was performed. The existing feature-first architecture, Riverpod
state/DI and centralized named Flutter routes remain in use.

## Reproduced findings and repairs

| Finding | Repair and evidence |
|---|---|
| Invalid/empty/sentinel laptop pairing codes issued valid tokens, and `/auth/pair/direct` could replace credentials without a code. | Require the owner's one-time code, return 401/422 for rejection, remove the direct endpoint/service bypass, consume codes using a conditional SQL update, and make the UI require the code. This restores the specification's laptop-pairing boundary; Pi exclusive enrollment is unchanged. |
| Sensitive backend tools executed immediately despite `requires_confirmation`. | Store one in-memory proposal per authenticated user. Return the tool to the existing Confirm/Cancel UI; `/assistant/tool-result` executes only the server-owned proposal with the matching user/request/tool. Cancellation, replay, wrong user/request/tool and superseding-query tests protect it. No model or client can supply replacement execution arguments. A lost acknowledgement reports uncertainty instead of success. |
| Allow-listed schedule update and memory deletion had no executor implementation; completed reminders were ignored. | Implement scoped schedule updates and memory deletion, and pass the requested reminder filter through. Tests assert real database effects. |
| Assistant HTTP fallback could send tokens/personal text to other hosts; reads could stall and failures were represented as empty results/success. | Use only the selected endpoint, validate resolved private addresses and connect to the checked IP, disable redirects/proxies, bound total request/body time and response size, abort late connections, propagate typed errors, close the client through Riverpod, and avoid replaying mutations. Preserve the most recent ten history messages. Real local HTTP tests cover request routing, auth, redirects, malformed/oversized responses and body/late-connection timeouts. |
| Invalid audio was assigned an invented five-second duration. Malformed history could reach internal exceptions. | Read at most the size limit plus one byte, validate history with Pydantic before temporary-file creation, inspect/decode real duration, reject unreadable/no-text audio and delete temporary recordings on failure. The current app's normal voice path remains phone-local. |
| Malformed model tool names/arguments could raise internal type errors. | Validate names, bounded text/boolean arguments, confirmation prompts and speech-rate values before executing tools. |
| Battery commands always announced 85%. | Inject a domain battery service with an Android BatteryManager MethodChannel adapter; use the actual percentage or report unavailable. Both command routes use it. No extra permission is needed. |
| Some speech-rate/torch commands reported success without applying/verifying the change. | Await the real speech-rate operation, propagate engine rejection, and check actual mobile torch state. Scanner torch feedback describes the request while its screen owns completion/error feedback. |
| Tracked `copy_key.exp` contained a plaintext SSH password and accepted host keys automatically. | Replace it with an argument-forwarding interactive SSH helper. No password or automatic host-key acceptance remains in that file. Previous Git revisions still contain the old value: the owner must rotate it if it is still used. History was not rewritten. |
| Dart unused imports and Python lint/format failures. | Remove unused imports, narrow exception handling, sort imports and format the touched code. Final static checks are recorded below. |

The first new backend regression run reproduced 18 failures out of 19 cases;
after repairs those 19 passed. Additional confirmation/data/filter/cleanup
cases were subsequently added. Tests were retained, not deleted or suppressed.

## Commands and final verification

Unless noted, Flutter commands ran from `mobile_app/`, backend commands from
`laptop_backend/`, and Pi/shell/model checks from the repository root. `PI_ENV`
means absolute `PYTHONPATH=raspberry_pi/src` and
`AIBA_PI_PYTHON=laptop_backend/.venv/bin/python` paths resolved from the root.

| Command/check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 233 files, 0 changed, 0.36 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; no issues found, 3.1 s |
| `PI_ENV flutter --no-version-check test --no-pub --coverage --concurrency=4 -r expanded` | Exit 0; 376 passed, 0 failed/skipped, 15 s; real Python Pi simulator enabled |
| `.venv/bin/python -m pytest -q --tb=short` | Exit 0; 88 passed, 32 deprecation warnings, 0.94 s |
| `PYTHONPATH=raspberry_pi/src laptop_backend/.venv/bin/python -m pytest raspberry_pi/tests -q -rA` | Exit 0; 16 passed, including real local WebSocket enrollment/control/reconnect |
| `laptop_backend/.venv/bin/ruff check laptop_backend raspberry_pi` | Exit 0; all checks passed |
| `laptop_backend/.venv/bin/ruff format --check laptop_backend raspberry_pi` | Exit 0; 62 files already formatted |
| `laptop_backend/.venv/bin/python -m pip check` | Exit 0; no broken requirements; sandbox cache warning |
| `JAVA_HOME=<Android Studio jbr> ./gradlew :app:testDebugUnitTest --rerun --offline` from `mobile_app/android/` | Exit 0; BUILD SUCCESSFUL in 27 s; 8 tests, 0 failed/errors/skipped; fresh XML evidence dated 2026-10-09 |
| Java 21 `./gradlew testDebugUnitTest --offline` | Exit 1; BUILD FAILED in 17 s. Ten CameraX Robolectric class initializations cannot fetch `org.robolectric:android-all-instrumented:16-robolectric-13921718-i7`; `repo1.maven.org` DNS resolution fails. The Java-17 blocker is avoided, but the aggregate suite is not verified. |
| Java 21 `./gradlew :app:lintDebug --offline` | Exit 1; BUILD FAILED in 20 s; shared_preferences test lint model needs uncached AndroidX test/MockK/Mockito/Guava dependencies. No complete Android lint result is claimed. |
| `flutter --no-version-check build apk --debug` | Exit 0; assembleDebug 12.3 s; APK built; existing Kotlin-plugin migration warnings remain |
| `flutter --no-version-check build apk --release --target-platform android-arm64` | Exit 0; assembleRelease 11.9 s; signed APK built, 178,278,687 bytes |
| APK signature and ZIP inspection | Signature verification exit 0; both packaged LiteRT hashes match metadata; no `.env`, `.db`, `.sqlite`, `.jks`, or `.pem` entries. This is a targeted packaging check, not a formal secret audit. |
| LiteRT CPU/XNNPACK smoke using root `.venv/bin/python` | Both models allocate/invoke with zero and seeded synthetic inputs; tensor contracts `[1,3,320,320]` → `[1,84,2100]` / `[1,605,2100]` match metadata; all outputs finite. This does not measure real-world detection quality or Android inference performance. |
| Model/label SHA-256 and count checks | Both model and label hashes match; COCO 80 and Open Images 601 labels present |
| Android source XML parsing | All source XML files parse |
| `sh -n` for four Pi scripts; `bash -n` for three root scripts | Exit 0; no syntax errors |
| `/usr/bin/expect copy_key.exp` without arguments | Expected exit 2; usage displayed; no SSH connection made |
| Live local Ollama synthetic prompt | Exit 0; `llama3.2:3b` returned valid structured JSON in 6.57 s; no personal text or cloud request |
| Cached Whisper `base`, synthetic locally generated audio | Exit 0; expected keyword recognized; temporary audio removed; no model download |
| `adb devices -l` | Exit 0 after allowing local daemon access; no devices attached |
| `git diff --check` and Stitch SHA-256 inventory | Exit 0; no whitespace errors; 31 tracked Stitch files, 0 missing, 0 changed |

Release APK SHA-256:
`6170f17b40ad112d698dc4e59932821467952c4be176ca8f69d475828f406abb`.
Artifacts are local candidates under `mobile_app/build/app/outputs/flutter-apk/`;
the existing deliverables and installed release were not replaced.

Earlier execution failures are retained as evidence: Flutter cache and localhost
socket access were initially sandbox-blocked and were rerun with authorized
access. Android lint's first offline attempt lacked `listenablefuture`; an
online retry stalled for over five minutes and was stopped, then bounded
checks isolated the remaining missing artifacts. Two release attempts with
`--no-pub` failed because debug metadata retained the development-only
`integration_test` registrant. The existing BUILD_AND_RUN.md explicitly warns
against this; using its normal release command regenerated the correct file
and passed. One new HTTP test initially lacked its `Completer` import; it was
corrected before final verification. Do not modify generated registrants or
third-party tests to hide these failures.

## Coverage and remaining acceptance

Measured Dart coverage: **6,429 / 10,478 lines (61.36%)** across 153 instrumented
Dart files; `lib/` contains 190 Dart files. This is not full-source coverage and
does not measure native Android, Python, real sensors, real scenes or every
behavior. The ignored coverage artifact is `mobile_app/coverage/lcov.info`.
Passing automated tests cannot prove perfection. The final passing suites total
488 cases (376 Flutter + 88 backend + 16 Pi + 8 app native); aggregate plugin
failures are excluded from that total. There are 48 added regression cases
(24 Flutter, 24 backend).

Remaining acceptance includes permission denial/revocation, live Android
camera and OCR quality, real battery/TTS/torch behavior, offline haptics,
TalkBack speech/focus and font/display scaling, repeated voice/lifecycle crash
cycles, real Gemini success/outage, Pi camera/NCNN artifacts and hardware,
exclusive enrollment/hotspot DHCP recovery and speaker ownership, WAN-disabled
sessions, and sustained latency/memory/battery/thermal testing. The tracked Pi
model directory contains checksums/instructions, not deployed NCNN binaries.
Scanner camera ownership remains presentation-layer debt (ISSUE-052).

Exact next action: install the debug candidate on the authorized target phone,
run the physical matrices in TESTING.md and PHONE_HOTSPOT.md, and record actual
outcomes. On a host with Maven access, rerun the Java 21 aggregate native tests
and Android lint. Restart/deploy the updated laptop backend before testing the
new one-time pairing and server confirmation behavior; the running backend
was not replaced during this audit.

## Change inventory and governance

New folders: none. Screens/routes: none. New domain contract:
`BatteryStatusService`; Android adapter and provider implement it through the
existing layered dependency injection. No second state-management approach,
cloud processing, camera upload, new authentication system or arbitrary tool
execution was introduced.

New tests: backend `test_audit_regressions.py`, Flutter
`http_assistant_repository_test.dart` and `device_command_test.dart`; existing
assistant-controller tests now assert server confirmation/cancellation and
truthful network-loss feedback. Test fixtures use synthetic content only.
New Markdown: this audit report. Updated Markdown: CURRENT_MODULE,
PROJECT_STATUS, AGENT_HANDOFF, CHANGELOG, INDEX, KNOWN_ISSUES, TESTING,
requirements-traceability, architecture and decision-log.

Source additions: battery domain service and Android adapter. Source changes:
assistant repository/provider/controller, voice command executor, connection
screen and defaults, TTS adapter, Android MainActivity, laptop schemas/router/
auth/main/data/tool validation, and the SSH helper. `local_commands.py` has
formatter-only changes. Existing unrelated camera, Scanner, wearable, model,
Stitch and documentation work was preserved; no release-signing identity,
Gradle configuration, production model or platform dependency was changed.

Requirements addressed by software evidence: FR-015, FR-018, FR-020,
FR-021, FR-022, NFR-SEC-002/003/004, NFR-REL-001 and NFR-MAINT-002.
Physical statuses remain open. Architecture/behavior rationale is ADR-064.

Git-style summary: `fix: enforce assistant trust and confirmation; verify
project suites, models and Android packaging`. No commit was created.

## Exact audit file inventory

Added by this audit (6):

```text
docs/PROJECT_AUDIT_2026-10-09.md
laptop_backend/tests/integration/test_audit_regressions.py
mobile_app/lib/domain/services/battery_status_service.dart
mobile_app/lib/infrastructure/device/android_battery_status_service.dart
mobile_app/test/features/assistant/device_command_test.dart
mobile_app/test/features/assistant/http_assistant_repository_test.dart
```

Modified by this audit (28, including already-modified files):

```text
copy_key.exp
docs/AGENT_HANDOFF.md
docs/CHANGELOG.md
docs/CURRENT_MODULE.md
docs/INDEX.md
docs/KNOWN_ISSUES.md
docs/PROJECT_STATUS.md
docs/TESTING.md
docs/architecture.md
docs/decision-log.md
docs/requirements-traceability.md
laptop_backend/src/ai_assistant/main.py
laptop_backend/src/ai_assistant/models/schemas.py
laptop_backend/src/ai_assistant/routers/assistant.py
laptop_backend/src/ai_assistant/routers/auth.py
laptop_backend/src/ai_assistant/services/auth.py
laptop_backend/src/ai_assistant/services/user_data.py
laptop_backend/src/ai_assistant/tools/local_commands.py
laptop_backend/src/ai_assistant/tools/registry.py
mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/MainActivity.kt
mobile_app/lib/app/assistant_providers.dart
mobile_app/lib/app/assistant_session_controller.dart
mobile_app/lib/app/voice_kernel/command_executor.dart
mobile_app/lib/core/constants/assistant_defaults.dart
mobile_app/lib/features/assistant/presentation/assistant_connection_screen.dart
mobile_app/lib/infrastructure/assistant/flutter_tts_speech_output_service.dart
mobile_app/lib/infrastructure/assistant/http_assistant_repository.dart
mobile_app/test/features/assistant/assistant_controller_test.dart
```

Pre-existing additions and modifications outside this inventory remain in the
workspace and are not attributed to the audit. The full workspace ended with
76 status entries; this is not the audit's changed-file count.
