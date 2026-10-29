# Vision AI demo reliability and rehearsal

Date: 2026-10-21. Module 75 / ADR-076. Software/build/in-place Pixel installation
verified. Owner confirms repeated commands and ready cue both work on Pixel; broader acoustic acceptance remains open, with no error-free claim.

## Result and scope

The owner reports wrong commands and missed listening while feedback speaks, and
requests a reliable demo build for 2026-10-22. Fixed concrete pause/recovery paths;
kept the existing offline English Vosk engine and deterministic local controls.
No new cloud speech path, provider migration, camera upload or audio retention.

- Native resume now returns true or a specific error; the adapter no longer
  silently reports successful resume. A three-second resume deadline is enforced.
- Echo-wake rejection and empty native callbacks restore capture. Command/wake
  callbacks are serialized; duplicate callbacks cannot overlap acknowledgement.
- Concurrent starts and recovery share work. Two recovery attempts precede an
  actionable error; stop/background/disposal invalidate stale work. Initial model
  start and recovery start have 15/12-second deadlines respectively.
- Activity resume waits for interrupted startup before opening a replacement.
  Native Activity pause stops cues/pauses recognition, and grammar switches retain
  pause state during feedback. The command trailing-silence allowance increases
  from 0.7 to 1.0 seconds for natural short pauses.
- Actual command readiness after wake acknowledgement or ordinary feedback may
  emit one 80 ms vibration and 100 ms tone, with 180 ms native cleanup. Outputs
  fail independently and old cleanup cannot cancel a replacement. The cue is
  optional/foreground/session gated and observes existing media settings. Skip it
  on idle timeouts, during reader playback and in Smart AI button mode.
- Assistant Settings describes turn-taking and offers Restart voice listening on
  failure without changing saved preferences, trust or keys.
- Explicit unknown-word markers/negation are rejected before positive command
  matching; observed ASR repairs respect whole-word boundaries. Missing words do
  not justify choosing an action. No new unmeasured accent aliases were added.

Ordinary commands still pause while Vision AI speaks. This work does not add
unrestricted interruption or prove recognition accuracy for the owner's accent.
Existing guarded document-reader interruption and button-only Smart AI remain.

## Architecture, state and routing

Feature-first layers, Riverpod DI/state and centralized named routes remain.
Existing kernel/controller owns audio/actions; widgets call the kernel. New domain
capability `VoiceListeningFeedback` contains no Flutter/Android dependency. Native
Vision AI cue output has its own bounded session and uses the existing speech
channel; Smart AI's cue and recorder implementations remain unchanged. No new
folder, screen, route, model or package dependency.

Before work: extensive dirty user workspace, 576 tracked/untracked source hashes
captured at `/tmp/aiba-vision-reliability-before-20261021.json`, 31 Stitch files.
No baseline work reverted or removed. No device initially; owner connected/unlocked
the Pixel for installation/rehearsal. No sub-agents, commit or push.

## Verification and exact command results

Commands run from `mobile_app/` unless stated otherwise.

| Command/check | Actual result |
|---|---|
| `dart format --output=none --set-exit-if-changed` on 10 changed Dart files | Exit 0; 10 files, 0 changed, 0.06 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, 2.8 s |
| Focused `flutter --no-version-check test --no-pub test/features/assistant/vision_listening_reliability_test.dart test/features/assistant/android_on_device_speech_recognition_service_test.dart test/domain/intent_resolver_test.dart test/features/assistant/voice_screen_commands_test.dart test/features/assistant/smart_ai_foreground_controls_test.dart -r expanded` | Initial focused pass: exit 0, 122 passed; later additions covered by full suite |
| `flutter --no-version-check test --no-pub test/features/assistant/vision_listening_reliability_test.dart -r expanded` | Final targeted exit 0; 12 passed, 1 s |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r compact` | Final exit 0; **673 passed**, 0 failures/skips, 21 s; real Python Pi simulator included, 21 more than baseline 652 |
| Android: `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --offline --console=plain` | Exit 0; BUILD SUCCESSFUL in 13 s; fresh XML **25 tests, 0 failures/errors/skips** (3 new) |
| `flutter --no-version-check build apk --debug --no-pub --target-platform android-arm64 --split-per-abi --build-name=1.4.18 --build-number=2058` | Exit 0; assembleDebug 10.1 s; ARM64 debug APK built |
| Same build flags with `--release` | Exit 0; assembleRelease 29.5 s; 126.3 MB ARM64 release APK built |
| SDK 36 `apksigner sign/verify --verbose --print-certs`, `zipalign -c -P 16 4`, `aapt dump badging`, DEX/AOT inspection | Exit 0; predecessor certificate matches, v2/v3 signing valid, 16 KiB alignment passes; 1.4.18/code 4058, DEBUGGABLE absent; new native cue/readiness method and Dart restart/failure messages present |
| Targeted `adb install --no-incremental -r deliverables/AI-Blind-Assistant-1.4.18-vision-ai-reliability.apk` | Exit 0; Performing Streamed Install; Success |
| Installed base-APK pull, SHA-256 and package metadata | Exact hash matches delivery; 1.4.18/code 4058; firstInstallTime 2026-10-21 14:30:57 retained; camera/microphone grants retained; DEBUGGABLE absent |
| Targeted `adb shell am start -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok, LaunchState UNKNOWN, MainActivity, WaitTime 3023 ms; do not claim app-only cold latency |
| Post-install process and filtered readiness/crash-marker check | Process alive; no matching readiness/Java-native fatal marker in inspected current-PID filtered output. Window-focus query yielded no matching rows; foreground/acoustics remain owner checks |
| Root `git diff --check` and baseline comparison | Exit 0 at verification; 31 Stitch reference hashes preserved, no baseline files removed; final inventory below |

Initial sandbox attempts for Flutter tests/Gradle/ADB could not access SDK/cache/
ADB socket; rerun with approved escalation. This was an environment permission
boundary, not hidden build success. Initial analyzer runs found two brace-style
findings each, corrected before the clean final run.

First full suite had 638 passes/35 failures: newly added timeout timers in
best-effort disposal outlived widget teardown. Removed that blanket timeout while
retaining explicit live resume/start/recovery deadlines; no test assertion was
deleted. Second full suite had 671 passes/2 failures: a stale startup left its
active flag set and the reader echo test expected no resume. Corrected stale
startup state; kept all reader no-action/no-speech-interruption assertions and
updated only its resume count to require the intended echo recovery. The focused
startup test initially drove an incomplete lifecycle transition; it now drives
inactive/hidden/paused/hidden/inactive/resumed. Final full suite passes all 673.

Existing Kotlin/Gradle migration warnings remain; both APK builds succeed. No
provider probe, test recording, secret readback, data clear, uninstall or pairing
rotation was performed.

## Artifacts

[Delivered Pixel update](../deliverables/AI-Blind-Assistant-1.4.18-vision-ai-reliability.apk)
is a release-mode APK signed with the existing Pixel predecessor's development
certificate for an in-place update. Source signing/version files are unchanged.
The separately project-signed Flutter release remains in build output. Previous
APKs are preserved. The optional generated incremental-signature sidecar was
moved to `/tmp/aiba-vision-1.4.18.apk.idsig`; it is not required for the verified
non-incremental installation and is not added to source.

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Delivered/installed APK | 126,355,367 | `9e190e7c036400f8e669b58511d349c441ba7caf9bc396280cb8b19c5d321503` |
| Project-signed release | 126,310,220 | `6c4a6cc41f082ff3c76b9aebc4958bdf4ce439f74925ec19d435b11d966bc398` |

## Tomorrow's short rehearsal

Keep the app open/unlocked, use the same quiet position/distance intended for the
demo and check media volume. Say Hey Vision AI and wait for Listening to finish
and its brief cue. Then use one command at a time, waiting for each reply/cue:

1. Open settings.
2. Go home.
3. What time is it.
4. Start mobile mode; after camera startup, pause detection, then resume detection.
5. Stop detection, then go home.
6. Open document scanner; frame a page, scan document, then pause reading and
   resume reading. Reader playback uses its existing guarded controls, without
   repeated new readiness tones.
7. Goodbye ends the session; another full wake opens a new one.

Use existing named screen controls if a spoken phrase fails. If listening is
stopped, use Assistant Settings > Restart voice listening. Pi demonstration still
requires its independently verified power/network/trust; do not infer that from
this voice update. Smart AI needs existing personal key/consent/internet only for
its explicit question capture; do not make a cloud question just to test local
controls. No error-free, exact-distance or mobility-replacement claims.

Physical owner acceptance: the owner selected “Commands and ready cue both work”
after the installed-Pixel wake/settings/home/time rehearsal request. Full accent/noise/overlapping-speaker/TalkBack/performance acceptance is
separate from software/package verification.

## Requirement IDs and next action

FR-013/014/015/021/022; NFR-ACC-001/002, NFR-OFFLINE-002, NFR-REL-001,
NFR-SEC-002/003, NFR-MAINT-002. ISSUE-085 software pause/recovery fixes pass;
ISSUE-083 acoustic acceptance and earlier Pi power/performance gates stay open.
Exact next action: repeat the short installed-Pixel rehearsal in the actual demo
room before the 2026-10-22 presentation. If a phrase is missed, use the named
buttons; do not save/upload microphone clips.

## File inventory and module checklist

Relative to the 576-file request baseline: 24 files modified, 6 files added,
0 removed. All 31 Stitch hashes match; 81 backend/Pi/governance/dependency
reference hashes are unchanged. The ignored delivery APK is an additional artifact. No folders or screens created; existing Assistant Settings refined.
Domain type added: optional VoiceListeningFeedback capability. New tests: 12
kernel reliability, 3 adapter, 6 resolver/word-boundary, 3 native cue cases; one
existing reader resume expectation updated while action/speech assertions remain.

### Added files

- `docs/VISION_AI_RELIABILITY_2026-10-21.md`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiListeningCue.kt`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiReadyCueSession.kt`
- `mobile_app/android/app/src/test/kotlin/com/example/ai_blind_assistant/VisionAiReadyCueSessionTest.kt`
- `mobile_app/lib/domain/services/voice_listening_feedback.dart`
- `mobile_app/test/features/assistant/vision_listening_reliability_test.dart`

### Modified files

- `deliverables/README.md`
- `docs/AGENT_HANDOFF.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_MODULE.md`
- `docs/INDEX.md`
- `docs/KNOWN_ISSUES.md`
- `docs/OFFLINE_VISION_ASSISTANT_GUIDE.md`
- `docs/PROJECT_STATUS.md`
- `docs/TESTING.md`
- `docs/architecture.md`
- `docs/assistant.md`
- `docs/decision-log.md`
- `docs/requirements-traceability.md`
- `docs/specification-baseline.md`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/MainActivity.kt`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`
- `mobile_app/lib/app/voice_kernel/vision_voice_kernel_v3.dart`
- `mobile_app/lib/domain/services/asr_correction_lexicon.dart`
- `mobile_app/lib/domain/services/intelligent_intent_resolver.dart`
- `mobile_app/lib/features/assistant/presentation/assistant_settings_screen.dart`
- `mobile_app/lib/infrastructure/assistant/android_on_device_speech_recognition_service.dart`
- `mobile_app/test/domain/intent_resolver_test.dart`
- `mobile_app/test/features/assistant/android_on_device_speech_recognition_service_test.dart`
- `mobile_app/test/features/ocr_scanner/scanner_reader_voice_test.dart`

### Required module completion record

1. Result: verified local listening reliability changes, installed 1.4.18 and
   bounded owner command/cue acceptance on Pixel.
2. Before implementation: extensive dirty workspace, 576-file baseline captured;
   no user work reverted and no baseline file removed.
3. Architecture: existing feature-first layers and single voice/controller owner.
4. State management: existing Riverpod DI/notifier.
5. Routing: existing centralized named AppRoute routes, no new route.
6. Folders created: none.
7. Screens created: none; Assistant Settings refined.
8. Domain types: optional VoiceListeningFeedback capability.
9. Tests: 21 new Flutter and 3 native cue cases; 673/25 total pass; reader echo
   expectation now requires microphone restoration, with other assertions intact.
10. Markdown created: this report.
11. Markdown updated: 14 living documentation/delivery files, listed above.
12. Requirements: FR-013/014/015/021/022; NFR-ACC-001/002, NFR-OFFLINE-002,
    NFR-REL-001, NFR-SEC-002/003 and NFR-MAINT-002.
13. Commands: format/analyze/focused/full/native/debug/release/sign/verify/
    alignment/install/launch/hash/diff; exact invocations above.
14. Exact results: final 673 Flutter/25 native pass; no analysis issues; 10-file
    format check has zero changes; intermediate failures/corrections recorded.
15. Android: both ARM64 builds pass (10.1/29.5 s), release-mode same-signer update
    installed in place, installed bytes match, Status ok/UNKNOWN launch.
16. Files added: six source/test/report files above, plus ignored APK artifact.
17. Files modified: 24 source/test/living-documentation files above.
18. Deliberately unchanged: AGENTS, Smart AI controller/provider/cue/recorder,
    backend, Pi, models/assets, dependencies, source signing/version, old APKs.
19. Stitch: all 31 hashes preserved.
20. Known issues: broader accent/noise/TalkBack, cue hardware/settings variation,
    inherited Kotlin migration warnings and independent Pi power/performance.
21. Deferred: ASR-engine benchmarking/model replacement and broad acoustic matrix;
    ordinary commands remain paused during speech. No error-free claim.
22. Exact next action: rehearse the listed local commands in the demo room before
    2026-10-22; wait for ready cue and retain named-control fallback.
23. Git-style summary: `fix(voice): recover local listening and signal readiness`;
    no commit or push.
