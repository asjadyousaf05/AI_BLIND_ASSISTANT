# Smart AI speech verification — 16 October 2026

## 1. Module result

Module 68's focused software repairs pass verification. The laptop default is
local Whisper medium, language configuration is honored, assistant-topic prompt
bias is removed, and decoding is deterministic. Unclear/repetitive segments
reject the entire utterance before query/command routing. Manual capture stops
shared TTS, cancels on background/disposal and removes transient clips after
success/failure. Audio 422/413 now offers speech recovery rather than declaring
an outage. Only the Smart AI Vosk conversation endpoint waits longer for pauses.

The owner explicitly approved paired-laptop Whisper, clear disclosure and clip
deletion. The paired screen explains this before Speak, and server success/
failure/limit cleanup tests pass. Specification/ADR-068 resolve the prior scope
conflict. Final checks: 128 backend/466 Flutter passes, earlier 13 native passes,
clean analysis/formatting, debug and signed release builds. Release 1.4.6/code
4046 is ready; no Android device is attached, so installation and physical voice/
deletion acceptance remain pending. Perfect recognition is not claimed.

The existing laptop launch service was restarted during the initial repair and
health recovered. This follow-up changes disclosure/tests/docs only; no second
backend restart or pairing rotation was needed.

## 2. Workspace state before implementation

The workspace already had extensive tracked modifications and untracked files,
including the active `test_local_commands.py`. A SHA-256 snapshot covered 525
tracked/nonignored files before edits. Existing changes were retained; the
active local-command test and command parser were deliberately left untouched.

## 3–5. Architecture, state management and routing

Existing feature-first layers, Riverpod dependency injection and centralized
named Flutter routes remain. No provider, authentication, command router or
network transport was added. ADR-068 records the model/recognition behavior.
The existing paired manual upload branch is now explicitly owner-approved under
the 2026-10-16 specification amendment and ADR-068 addendum. Temporary audio may
go only to the paired private-LAN laptop and must be deleted after processing.
Hands-free/unpaired speech stays phone-local, and Gemini receives no raw audio.

## 6–8. Folders, screens and domain types

None created. Existing backend transcription, application controller and native
speech adapter were used. Only the paired speech disclosure/related safety text
was added to the existing screen. Detection, Scanner, Pi and reader source were
left unchanged.

## 9. Tests created

- Twenty backend cases in `laptop_backend/tests/unit/test_transcription.py`:
  configured/overridden/automatic language, deterministic unprompted decoding,
  transcript preservation, whole-utterance rejection, empty audio, lazy decoder
  failures, private-error redaction, unavailable model, file bounds and HTTP
  rejection before query routing and temporary-file deletion after successful,
  unclear and over-duration requests. Tests use fakes/synthetic data, no model
  downloads or personal recordings. The name-preservation unit test is mocked;
  actual recognition evidence is separately reported below.
- Seven Flutter cases: shared speaker stopped before capture, cleanup on success
  and network failure, background cancellation, and audio HTTP 422/413 recovery
  with cleanup, plus the pre-Speak destination/deletion disclosure without an
  automatic question or microphone start. Existing offline, Smart AI, Scanner
  and reader regressions pass.

## 10–11. Markdown created and updated

Created this verification record. Updated `CURRENT_MODULE.md`,
`PROJECT_STATUS.md`, `CHANGELOG.md`, `AGENT_HANDOFF.md`,
`requirements-traceability.md`, `decision-log.md`, `KNOWN_ISSUES.md`,
`assistant.md`, `BUILD_AND_RUN.md`, `INDEX.md`, `laptop_backend/README.md`,
`AGENTS.md`, `specification-baseline.md` and `architecture.md`.
Historical sections retain their dates; new notes correct current-source claims.

## 12. Requirement IDs addressed

FR-013/014/019/022, BR-003, NFR-REL-001 and NFR-MAINT-002 gain software evidence.
NFR-SEC-003 gains cleanup/cancellation/disclosure evidence and explicit narrow
owner authorization. FR-014/NFR-SEC-003 are implemented with physical acceptance
open; ISSUE-075's scope conflict is resolved. Physical statuses are not promoted.

## 13–14. Commands and exact results

Commands ran from the project root unless the directory is shown.

| Command/check | Result |
|---|---|
| `pwd`, `git status --short`, ordered guide/document reads and `rg` source tracing | Workspace identified; existing edits preserved; two speech paths identified |
| Initial source search for `laptop_backend/src/ai_assistant/core` | Exit 2: directory does not exist; actual settings are in `config.py` |
| Initial search for Vosk `graph/words.txt` | Exit 2: not present in the packaged model; no vocabulary claim inferred |
| `say -v '?'` and synthetic generation with Rishi/Samantha | Exit 0; temporary synthetic clips only |
| Local-cache-only base/medium comparison using `faster_whisper.WhisperModel` | Exit 0; base produced “Quaid IASM University”, medium “Quaid-i-Azam University” for the same Rishi clip; load+decode 0.88 s/3.75 s respectively |
| Backend `.venv/bin/ruff format src/ai_assistant/services/transcription.py src/ai_assistant/config.py scripts/prepare_whisper_model.py tests/unit/test_transcription.py` | Exit 0; one new test file formatted, three unchanged |
| Backend `.venv/bin/ruff check src tests scripts` | Exit 0; All checks passed |
| Backend `.venv/bin/python -m pytest tests/unit/test_transcription.py -q --tb=short` | Exit 0; **17 passed**, 3 deprecation warnings, 0.26 s |
| Backend `.venv/bin/python -m pytest -q --tb=short` | Exit 0; **125 passed**, 33 deprecation warnings, 0.93 s |
| Backend `.venv/bin/ruff format --check src tests scripts` | Exit 0; 36 files already formatted |
| `dart format lib/app/assistant_session_controller.dart test/features/assistant/assistant_controller_test.dart` in `mobile_app/` | Exit 0; final check reports two files, zero changed |
| First sandboxed Flutter targeted-test attempt | Exit 1: SDK engine cache outside workspace was unwritable; permitted rerun used the existing SDK cache |
| First permitted controller-test run | Exit 1: new test lacked `AppLifecycleState` import; added Flutter widgets import, reran successfully; no test deleted |
| Corrected controller suite | Exit 0; **38 passed** before the additional two HTTP recovery cases |
| `flutter --no-version-check analyze --no-pub` in `mobile_app/` | Exit 0; No issues found, 3.4 s |
| `flutter --no-version-check test --no-pub test/features/assistant test/domain/reader_voice_command_policy_test.dart test/features/ocr_scanner/scanner_reader_voice_test.dart -r expanded` | Exit 0; **130 passed**, 4 s |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **465 passed**, no failures/skips, 15 s; existing real Pi simulator enabled; no Pi source change |
| `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain` in `mobile_app/android/` | Exit 0; BUILD SUCCESSFUL in 23 s; fresh XML: **13 tests**, zero failures/errors/skips |
| `flutter --no-version-check build apk --debug --target-platform android-arm64` | Exit 0; assembleDebug 17.0 s; debug APK built; existing Kotlin/Gradle migration warnings remain |
| `laptop_backend/.venv/bin/python laptop_backend/scripts/prepare_whisper_model.py --help` | Exit 0; tiny/base/small/medium choices, medium default; no download performed |
| Ignored environment check | No `laptop_backend/.env` exists; no environment/secrets file was created or modified |
| `launchctl print gui/501/com.ai-blind-assistant.backend` filtered to state/PID | Exit 0; existing service running before restart; no environment/credential output |
| `launchctl kickstart -k gui/501/com.ai-blind-assistant.backend` | Exit 0; only this existing service restarted |
| Filtered localhost `/health` request | Exit 0; status ok, protocol 1, provider Ollama, AI available true, Ollama available true; health does not expose/prove Whisper model identity |
| Initial sandboxed `adb devices -l` | Exit 1: daemon socket denied (`Operation not permitted`); no device availability inferred and no installation attempted |
| SHA-256 file/preservation audit, local-link check and `git diff --check` | Exit 0; 18 modified/two added, zero unexpected/missing; 31 Stitch hashes unchanged; 87 relative documentation links resolve |

Python 3.14 asyncio and Starlette/httpx/status-code deprecation warnings are
existing maintenance issues; no dependencies were changed for this repair.
Aggregate plugin tests/lint were not rerun in this scope.

### Owner-approval follow-up commands

| Command/check | Exact result |
|---|---|
| Backend `.venv/bin/ruff format tests/unit/test_transcription.py` and `.venv/bin/ruff check src tests scripts` | Exit 0; one file formatted; All checks passed |
| Backend `.venv/bin/python -m pytest -q --tb=short` | Exit 0; **128 passed**, 35 deprecation warnings, 0.84 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, 2.7 s |
| `flutter --no-version-check test --no-pub test/features/assistant -r expanded` | Exit 0; **88 passed**, 2 s; includes disclosure and 2× text layout |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **466 passed**, zero failures/skips, 13 s |
| `flutter --no-version-check build apk --debug --target-platform android-arm64` | Exit 0; assembleDebug 9.2 s, APK built |
| `flutter --no-version-check build apk --release --split-per-abi --target-platform android-arm64 --build-name=1.4.6 --build-number=2046` | Exit 0; assembleRelease 31.5 s, ARM64 APK 125.9 MB; build-time version overrides only, `pubspec.yaml` unchanged |
| Java 21 `build-tools/36.0.0/apksigner verify --verbose <release-apk>` | Exit 0; Verifies, v2 signature true, one signer |
| `build-tools/36.0.0/aapt dump badging <release-apk>` filtered to package/SDK/ABI/debuggable | Exit 0; package com.example.ai_blind_assistant, version 1.4.6/code 4046, SDK 24/target 36, arm64-v8a, no debuggable marker |
| `adb devices -l` with permitted daemon access | Exit 0; daemon started, empty attached-device list; no installation or device data change |
| Final Python/Dart format checks and `git diff --check` | Exit 0; 36 Python files formatted; two changed Dart files, zero formatting changes; no whitespace errors |
| Final SHA-256 preservation and relative-link audit | Exit 0; 23 existing files modified/two added, zero missing/unexpected; approval follow-up changes 16 scoped files; all 31 Stitch hashes and active local-command test unchanged; 90 relative links resolve |

Native code was not changed during this disclosure follow-up; its earlier 13
fresh test passes remain the applicable evidence. The initial sandbox-only ADB
failure is superseded by the permitted empty-device-list result above.

## Synthetic runtime evidence and its limits

Temporary output was generated locally with macOS `say`, not recorded from a
person. Cached medium was exercised through the production provider with
`local_files_only=True`, configured English, temperature zero, no topic prompt
and VAD. After model loading, observed results were:

| Synthetic input | Actual result | Decode time |
|---|---|---|
| Rishi: “What do you know about Quaid i Azam University?” | “What do you know about Quaid-i-Azam University?” | 2.73 s |
| Samantha: same question with a 1.2-second internal pause | “What do you know about Cade IASM University?” | 2.91 s |
| Rishi: “Please do not start mobile mode. Explain how offline speech recognition works.” | Negation retained, but “offline” became “appliance” | 3.58 s |
| One second of synthetic silence | `No speech detected in the audio.`; no transcript | 0.02 s |

The larger model fixes one reproducible example but still makes confident word
errors. These four clips are not an accuracy benchmark, intended-user accent
acceptance, phone-microphone test or evidence of perfect recognition. No
proper-name substitutions were hardcoded. Temporary clips were removed.

The [faster-whisper implementation](https://github.com/SYSTRAN/faster-whisper/blob/master/faster_whisper/transcribe.py)
documents decoding/language options and the default -1.0 log-probability/2.4
compression thresholds used for rejection. These scores do not guarantee word
correctness. The [official Vosk model list](https://alphacephei.com/vosk/models)
distinguishes small mobile models from larger server models; the phone's
bundled English hands-free model was not replaced here.

## 15. Android build result

Both current artifacts build successfully:

| Artifact under `mobile_app/build/app/outputs/flutter-apk/` | Bytes | SHA-256 |
|---|---|---|
| `app-debug.apk` | 832,904,380 | `1c0742e03d2d0b7406c30bb5830f912cb37b6e4c62d5280e5be41681a6543b86` |
| `app-arm64-v8a-release.apk` | 125,916,832 | `2657c098694c9c0dde2983a4f268b186021bc56b93e9c36b101e66360fd75786` |

The release uses existing signing configuration and explicit build-time version
1.4.6/base code 2046 (ARM64 split code 4046). Source version/signing files were
not changed. Signature verification passes; release is not debuggable. No
Android device is attached and the phone application remains unchanged.

## 16–17. Files added and modified

Added:

- `laptop_backend/tests/unit/test_transcription.py`
- `docs/SMART_AI_SPEECH_VERIFICATION_2026-10-16.md`

Modified production/setup/test files:

- `laptop_backend/src/ai_assistant/services/transcription.py`
- `laptop_backend/src/ai_assistant/config.py`
- `laptop_backend/scripts/prepare_whisper_model.py`
- `laptop_backend/.env.example`
- `laptop_backend/README.md`
- `mobile_app/lib/app/assistant_session_controller.dart`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`
- `mobile_app/test/features/assistant/assistant_controller_test.dart`
- `mobile_app/lib/features/assistant/presentation/assistant_screen.dart`
- `mobile_app/test/features/assistant/assistant_screen_test.dart`

The thirteen additional modified files are the ten original living `docs/`
files, `AGENTS.md`, `docs/specification-baseline.md` and `docs/architecture.md`.
Totals: 23 existing files modified, two added, none deleted.

## 18–19. Deliberately unchanged files and Stitch preservation

The active `laptop_backend/tests/unit/test_local_commands.py`, its command
parser/router, UI outside the speech disclosure, Scanner/reader, detection/model assets, Pi source,
dependencies/lockfiles, signing/version files, pairing, credentials, and all
other initial edits are untouched. All 31 tracked Stitch-related file hashes
match the start-of-task snapshot. No commit or push.

## 20–21. Known issues and deferred work

- ISSUE-074/043: names, accents/noise, handset capture, echo, latency and physical
  acceptance remain open. Whisper's model upgrade affects laptop transcription;
  hands-free still uses the phone's smaller Vosk model. A low score can trigger
  retry; a confidently wrong transcript can still pass.
- ISSUE-075's scope conflict is resolved by explicit owner approval, amended
  specification, architecture/agent instructions and disclosure before Speak.
  Audio remains private-laptop-only and transient; physical cleanup and privacy
  acceptance remain open. No hands-free audio upload or cloud speech was added.
- Existing unrelated known issues remain. No other feature repair, on-device
  Whisper integration, new model download or phone install.

## 22. Exact next action

Connect the intended Android phone, verify its existing release signer/package,
then install `app-arm64-v8a-release.apk` with `adb -s <device> install
--no-incremental -r <release-apk>` without uninstalling, clearing data or rotating
pairing. Verify the installed hash/version and launch. Compare the owner's
university question using the Speak button separately from hands-free. Record
actual displayed words, quiet/TV/fan, natural pauses, speaker echo, silence,
Cancel/background behavior and latency. Preserve offline controls and pairing;
do not treat this synthetic evidence as physical acceptance.

## 23. Git-style summary

`fix(assistant): improve local question transcription and microphone recovery`

23 existing files modified; two added; zero deleted; unrelated work preserved.
128 backend + 466 Flutter + earlier 13 native passes; analysis/format/debug and
signed release builds pass. Explicit laptop-speech consent is documented.
Only the existing laptop service restarted; no phone install, commit or push.
