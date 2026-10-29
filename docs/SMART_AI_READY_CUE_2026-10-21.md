# Smart AI ready vibration and chime verification

Date: 2026-10-21. Module 72 / ADR-073. Software/build/artifact verified; owner requested later physical testing.

The owner confirms the hold interaction and other Smart AI behavior works, but
still feels no haptic and requests an audible readiness signal. The current
request is confined to recording-ready feedback. Prior Module 71 implementation
and uncommitted source are preserved, including the final speech-interruption
correction that was built but not installed before the earlier turn stopped.

## Implementation

After native recording reports success, the existing Smart AI controller calls
its injected audio coordinator for one 220 ms vibration and a 160 ms prompt tone.
The new isolated Android bridge classifies vibration as accessibility on API33+
and uses accessibility audio attributes below that. Strong amplitude is requested
only on supported devices; otherwise default amplitude. The old installed plugin
uses alarm attributes, verified from local source. This difference alone does
not establish the cause of the owner's missing physical vibration.

The chime is generated locally with ToneGenerator's prompt tone at 65% generator
gain on the media stream. It uses the existing route/volume and never changes
system settings or overrides DND. No stored audio, asset download, API, TTS,
permission, dependency, background service or worker. One output failure cannot
prevent attempting the other. Native resources release after 300 ms; stale cleanup
cannot stop a newer cue. Native play is foreground-gated. Submit/cancel/Activity
pause/exit stop feedback. Dart bridge calls are capped at 750 ms.

Actual cue-start failures become labelled fallback guidance, with recording
remaining usable. Native success indicates a request was accepted, not that a
person felt/heard it. The renamed Test listening vibration and sound action is
local-only; visible, semantic and spoken guidance now name both cues.

## Scope and workspace

568-file pre-request hash snapshot preserves already dirty source/docs/test work.
Vision AI/kernel/recognizers/grammars/shared TTS, backend/Pi, camera/models,
provider/model/key/privacy/recording/language/exit policies, dependencies/source
version/signing configuration remain unchanged. MainActivity only registers the
new feedback bridge and forwards its lifecycle. All Stitch files remain references.
No credentials, audio, screenshots of keys, provider tests, commits or pushes.

ADB initially reports no device. Owner explicitly selected “Finish the APK;
I'll test later.” Build a matching-phone-signer APK, but do not install or claim
physical acceptance. Exact verification, artifact and final inventory follow.

## Primary sources

[Android ToneGenerator](https://developer.android.com/reference/android/media/ToneGenerator)
documents bounded prompt playback and releasing resources.
[Android VibrationAttributes](https://developer.android.com/reference/android/os/VibrationAttributes)
and [Vibrator](https://developer.android.com/reference/android/os/Vibrator)
document accessibility usage and supported waveform/amplitude APIs.

## Exact commands and results

Flutter commands ran in mobile_app; Gradle in mobile_app/android.

| Command/check | Result |
|---|---|
| Scoped dart format, then --output=none --set-exit-if-changed | Exit 0; 9 files, zero changes |
| flutter --no-version-check analyze --no-pub | Exit 0; No issues found, 3.0 s |
| AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded | Exit 0; 615 passed in about 18 s; real Python simulator, 9 new cases from 606 |
| JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain | Exit 0; BUILD SUCCESSFUL in 3 s; 21 tests, 0 failures/errors/skips; 4 new from 17 |
| flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi --build-name=1.4.15 --build-number=2055 | Exit 0; assembleDebug 19.3 s |
| Same build with --release | Exit 0; assembleRelease 31.8 s |
| apksigner sign/verify; predecessor certificate SHA-256 comparison | Pass; existing phone development signer, source signing unchanged |
| zipalign -c -P 16 4; aapt dump badging | Pass; 16 KiB alignment, 1.4.15/code 4055, min API24/target36; DEBUGGABLE absent |
| APK AOT/Dex inspection and copied delivery checksum | Pass; updated label/native handler packaged; delivery bytes identical |
| git diff --check; baseline preservation; credential-shaped literal scan | Exit 0; 31 Stitch/94 protected source hashes unchanged, 0 removals, 0 credential-shaped literals |
| ADB/device installation | No attached device; owner requested APK for later testing; no installation attempted |

First native pass took 27 s; the final rerun above includes the native foreground
lifecycle guard. First full Flutter run: 614 passed / 1 new test failed due to
concurrent lifecycle/teardown cancellation deleting the fake recorder's same path
twice. The fake now relinquishes owned path before asynchronous I/O, matching the
existing production recorder. All assertions remain; no tests deleted or skipped.
Final 615-case run passes. Kotlin/Gradle plugin migration warnings remain; builds
succeed. The native result is the app task, not aggregate plugin/lint acceptance.

## Artifacts

- Project-signed release: 126,244,684 bytes; SHA-256
  a22f54479dd2f22ebd64691f491c6403712c5480c8f7ed89e4c70fd5170a4b64.
- Matching-phone-signer release: 126,289,831 bytes; SHA-256
  74c23166df106172afe88605cac71f72e88a97819e590c873228e1d39b13c5c0.
- Identical ignored delivery:
  [AI-Blind-Assistant-1.4.15-smart-ai-ready-cue.apk](../deliverables/AI-Blind-Assistant-1.4.15-smart-ai-ready-cue.apk).

No install, data clear, pairing rotation, key readback or source signing/version
change. Older APKs preserved. Install this as an update, use Test listening
vibration and sound, then hold until ready and cancel after checking the cue.
Do not send a blank recording just to test hardware. Physical feeling/audibility
and full TalkBack/noise/volume/route acceptance remain pending.

## Required completion record

1. Module result: isolated readiness feedback implemented, APK verified; hardware acceptance deferred by owner.
2. Workspace before: 568-file snapshot, extensive earlier dirty work preserved; no commit/push.
3. Architecture: existing feature-first layers, injected audio boundary, isolated native feedback bridge.
4. State management: existing Riverpod.
5. Routing: existing centralized routes unchanged.
6. Folders: existing source/native/test/docs folders reused; none created.
7. Screens: no new screen; existing Smart AI hints/test control updated.
8. Domain types: existing SmartAiAudioCoordinator gains stopRecordingCue; no new domain entity.
9. Tests: one Dart cue test file/four native session tests; existing controller/widget/fakes strengthened; 9 Dart + 4 Kotlin new cases.
10. Markdown created: this report.
11. Markdown updated: exact scoped inventory below.
12. Requirements: FR-013/014, NFR-ACC-001/002, NFR-REL-001, NFR-MAINT-002.
13. Commands: scoped format, analysis/full tests, app-native tests, debug/release builds, signing/alignment/package/preservation checks.
14. Results: exact command table above; 615 Flutter/21 native pass, clean analysis.
15. Android: 1.4.15/code 4055 ARM64 debug/release pass; matching-phone-signer delivery verified; no install requested.
16. Files added: 5 source/test/report files below; ignored delivery APK additional.
17. Files modified: 23 existing source/test/docs files below.
18. Deliberately unchanged: Vision AI/kernel/recognizers/grammars/shared TTS/backend/Pi/camera/models/providers/keys/dependencies/source version/signing/routes.
19. Stitch: all 31 hashes preserved; no original removal.
20. Known issues: physical haptic/chime pending; OEM/system policy and media volume/route may affect output. Native start success is not sensory acceptance.
21. Deferred: installation/physical motor/speaker/TalkBack/noise/route checks, per owner's later-testing choice.
22. Exact next action: install APK as update, test both cues locally, then verify hold-ready cue and cancel; report felt/heard result.
23. Git-style summary: feat(smart-ai): add bounded microphone-ready vibration and chime.

## Scoped inventory

Modified relative to the pre-request snapshot:

```text
mobile_app/lib/app/smart_ai_cloud_controller.dart
mobile_app/lib/app/smart_ai_cloud_providers.dart
mobile_app/lib/domain/services/smart_ai_audio_coordinator.dart
mobile_app/lib/features/assistant/presentation/smart_ai_cloud_screen.dart
mobile_app/lib/infrastructure/assistant/smart_ai_recording_cue.dart
mobile_app/test/features/assistant/smart_ai_cloud_controller_test.dart
mobile_app/test/features/assistant/smart_ai_cloud_screen_test.dart
mobile_app/test/helpers/smart_ai_cloud_fakes.dart
deliverables/README.md
docs/AGENT_HANDOFF.md
docs/BUILD_AND_RUN.md
docs/CHANGELOG.md
docs/CURRENT_MODULE.md
docs/INDEX.md
docs/KNOWN_ISSUES.md
docs/PROJECT_STATUS.md
docs/TESTING.md
docs/architecture.md
docs/assistant.md
docs/decision-log.md
docs/requirements-traceability.md
docs/specification-baseline.md
mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/MainActivity.kt
```

Added source/test/report files:

```text
docs/SMART_AI_READY_CUE_2026-10-21.md
mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/SmartAiCueSession.kt
mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/SmartAiRecordingCueHandler.kt
mobile_app/android/app/src/test/kotlin/com/example/ai_blind_assistant/SmartAiCueSessionTest.kt
mobile_app/test/features/assistant/smart_ai_recording_cue_test.dart
```

## Later authorized phone installation — 2026-10-21

The owner subsequently connected the phone and requested installation/testing.
Matching-development-signer **1.4.15/code 4055** installed via
`adb install --no-incremental -r` (Success). Pulled installed bytes match the
126,289,831-byte delivery SHA-256 above; DEBUGGABLE is absent and the original
first-install time is retained. Foreground reentry reports Status ok/HOT,
TotalTime 298 ms / WaitTime 305 ms; the initial locked-screen launch was UNKNOWN,
not a verified cold launch. Process alive, zero current-process Java/native
fatal markers. Media volume 15/15. The phone repeatedly locked or switched apps;
the test button was not found in the inspected app hierarchy, and no successful
automated cue activation or specific felt/heard confirmation occurred. The next
owner request says everything looks perfect but does not establish separate
haptic/chime acoustic acceptance. No provider request or recording was made.
