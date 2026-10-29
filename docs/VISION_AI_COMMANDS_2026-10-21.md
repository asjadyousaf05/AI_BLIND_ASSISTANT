# Vision AI action feedback and screen commands

Date: 2026-10-21. Module 73 / ADR-074. Software, packaging and in-place phone installation verified;
new-command physical acoustic acceptance pending.

## Result and approved scope

The owner requests spoken progress/results when connecting Raspberry Pi or
starting Mobile Mode, local commands while Smart AI is idle/paused, screen-aware
controls and natural variants including can you please go back, go home, Listen
Vision AI, open about page and open setting. This explicitly extends Vision AI;
older Smart-AI-only edit restrictions belong to their historical modules.

The command executor reports finding before discovery, connecting before the
connection attempt, and a verified result. Not found gives same-Wi-Fi/hotspot/
power guidance. Discovery failure, multiple devices, connection failure and
already connected have distinct results; connecting does not claim detection
has begun. Mobile startup speaks camera preparation and succeeds only in Active;
permission-required, error, paused and busy states cannot report it started.
Pause/resume/stop wearable results check the confirmed phase.

Smart AI button mode opens a direct foreground local command session on entry,
after capture and on pause. A second wake or button hold is unnecessary for go
back/go home/settings/about. Explicit capture releases local AudioRecord; exit
restores the saved global preference. Ordinary local speech cannot enter legacy
Smart AI conversation or cause a provider request. A local command stops a pending
Smart AI reply/restores its locale before feedback. Releasing idle or paused Smart
AI cannot stop the new navigation acknowledgement. Existing capture bounds,
provider models, personal keys, consent, languages and circle behavior remain.

Visible route changes synchronize the existing kernel context after Navigator's
build. Previous-screen disposal cannot overwrite it. Returning from settings to a
reader restores reader context. Go home clears covered screens; go back navigates
one screen, while previous line moves through the document. Short pause/resume/
stop verbs resolve in their visible feature context. Manual controls share the
context gate. Bounded native grammars include polite phrases and setting/about
variants; Listen Vision AI is a branded wake phrase with matching TTS echo guard.

The kernel owns progress speech/echo protection and does not resume the microphone
between progress and action completion. Concurrent local actions are suppressed.
No extra recognizer/thread/provider/camera upload, dependency, version/signing
source configuration or network protocol change. New visible/spoken/semantic
Smart AI guidance explains the direct controls.

## Workspace and architecture

The workspace was already heavily dirty on feature/offline-assistant-audio at
d88b11b. The 573-file SHA-256 snapshot
`/tmp/aiba-vision-routing-before-20261021.json` predates this work. Existing
uncommitted source/docs/assets/tests are preserved. No commit, push, uninstall,
data clear, key embedding/rotation, provider probe or test deletion occurred.
Feature-first Flutter architecture, Riverpod Notifier/providers and centralized
RoutePaths/AppRouter/Navigator remain. No new screens, folders, domain types,
state-management library or routing library.

## Verification

Commands ran in mobile_app unless stated otherwise.

| Command/check | Actual result |
|---|---|
| `dart format --output=none --set-exit-if-changed <14 changed/new Dart files>` | Exit 0; 14 files, 0 changed, 0.07 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, 3.8 s |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **646 passed**, no failures/skips, 19 s, actual Python Pi simulator enabled; 31 more than 615 |
| Android: `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain` | Exit 0; BUILD SUCCESSFUL, 2 s; fresh app XML **22 tests, 0 failures/errors/skips**, 1 more than 21 |
| `flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi --build-name=1.4.16 --build-number=2056` | Exit 0; ARM64 debug APK, assembleDebug 9.9 s |
| `flutter --no-version-check build apk --release --target-platform android-arm64 --split-per-abi --build-name=1.4.16 --build-number=2056` | Exit 0; ARM64 release APK, assembleRelease **924.1 s**, 126.3 MB |
| SDK 36 `apksigner verify --verbose --print-certs`, matching-signer development-key signing, `zipalign -c -P 16 4`, `aapt dump badging` | Exit 0; installed predecessor certificate matches, v2 signature/alignment valid, 1.4.16/code 4056, ARM64, min SDK 24/target 36, DEBUGGABLE absent |
| ZIP/AOT inspection and SHA-256 | Packaged Dart finding feedback/native Listen/polite grammar present; delivery bytes equal signed candidate |
| `adb install --no-incremental -r deliverables/AI-Blind-Assistant-1.4.16-vision-ai-commands.apk` | Exit 0; Performing Streamed Install; Success |
| Pull installed base APK and package metadata | SHA-256 matches delivery; version 1.4.16/code 4056, DEBUGGABLE absent; firstInstallTime **2026-10-15 07:27:09** preserved, lastUpdateTime **2026-10-21 14:20:39** |
| `adb shell am start -S -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok, **LaunchState UNKNOWN (0)**, WaitTime **3073 ms**; phone locked, not verified COLD foreground |
| App process and current-PID crash-buffer check | App alive, **0 Java/native fatal markers**; NotificationShade focused/deviceLocked=1, no app accessibility nodes |
| `git diff --check` and request-baseline hashes | Exit 0; 573-file baseline, 31 Stitch/78 backend+Pi/7 production-asset/5 dependency-version-signing-guide hashes unchanged; zero baseline removals |

The first targeted run had one timing assertion failure (109 passed): the real
stream callback and route microtasks had not completed in the widget test's fake
clock. The test now permits those real callbacks and still asserts Home's context;
cleanup uses runAsync for the bounded native cue-stop call. A subsequent focused
run passed 10 tests; both later full runs passed (639 then final 646 after added
restored-reader and wearable-outcome coverage). Initial analyzer style findings
were corrected; all assertions remain. Native's new test exposed Scanner's missing
go home phrase; the shared navigation alternatives now include home/settings.
The first native run failed that assertion; one rerun before the edit repeated
it after a wrong-directory edit failed; final native results above pass. No failure
was bypassed. Existing Kotlin plugin migration/Gradle deprecation warnings remain;
this task's native result covers app unit tests, not every plugin/lint task.

New regressions cover progress-before-await, no mid-action microphone resume,
duplicate action suppression, no discovery success on failure, multiple devices,
confirmed connection/already-connected, active/permission/error/paused mobile
outcomes, wearable phase confirmation, manual context restrictions, every feature's
navigation variants, short-verb disambiguation, direct idle/paused Smart AI back,
recording handover, disabled-preference restoration, reader-context restoration,
Home stack cleanup and speech-release ownership. The legacy repository throws if
a local control contacts it. Native coverage checks branded Listen wake, negative
wake samples and polite navigation in both focused grammars. No paid/provider
request was used for verification.

## Device and physical acceptance

The authorized USB phone remains connected. The preceding 1.4.15 installed
successfully and kept its first-install time; its detailed runtime follow-up is
recorded in SMART_AI_READY_CUE_2026-10-21.md. The owner initially unlocked the phone for the
1.4.16 check, but it locked again by the post-install launch. Installation and
process checks pass as recorded above. A fresh asynchronous check asks the owner
to unlock/open Smart AI and say can you please go back without holding the circle.
No physical reply has been received yet. The agent did not bypass the lock screen,
change device sleep settings, record speech or submit a cloud question.
Software tests prove routing/ownership/controller handling, not recognition under
real accents/noise, audible TTS or TalkBack. Pi power-quality issue ISSUE-076 and
specific haptic/chime acceptance ISSUE-082 remain separate physical gates.

## Requirement evidence

FR-003/004/013/014/015/019/021/022; NFR-ACC-001/002, NFR-OFFLINE-002,
NFR-REL-001, NFR-SEC-002/003 and NFR-MAINT-002. This strengthens software
verification without promoting physical acceptance.

## File inventory and handoff

Relative to the pre-request snapshot: **31 modified files, 2 added files, 0
removed**; the ignored deliverable APK is an additional artifact. Exact inventory:


### Added

- `docs/VISION_AI_COMMANDS_2026-10-21.md`
- `mobile_app/test/features/assistant/voice_screen_commands_test.dart`

### Modified

- `deliverables/README.md`
- `docs/AGENT_HANDOFF.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_MODULE.md`
- `docs/INDEX.md`
- `docs/KNOWN_ISSUES.md`
- `docs/OFFLINE_VISION_ASSISTANT_GUIDE.md`
- `docs/PROJECT_STATUS.md`
- `docs/SMART_AI_READY_CUE_2026-10-21.md`
- `docs/TESTING.md`
- `docs/architecture.md`
- `docs/assistant.md`
- `docs/decision-log.md`
- `docs/requirements-traceability.md`
- `docs/specification-baseline.md`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiSpeechGrammar.kt`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiWakePhrase.kt`
- `mobile_app/android/app/src/test/kotlin/com/example/ai_blind_assistant/VisionAiWakePhraseTest.kt`
- `mobile_app/lib/app/router/app_route_observer.dart`
- `mobile_app/lib/app/smart_ai_cloud_controller.dart`
- `mobile_app/lib/app/smart_ai_cloud_providers.dart`
- `mobile_app/lib/app/voice_kernel/command_executor.dart`
- `mobile_app/lib/app/voice_kernel/vision_voice_kernel_v3.dart`
- `mobile_app/lib/domain/services/intelligent_intent_resolver.dart`
- `mobile_app/lib/domain/services/tts_echo_guard.dart`
- `mobile_app/lib/features/assistant/presentation/smart_ai_cloud_screen.dart`
- `mobile_app/lib/infrastructure/assistant/localized_smart_ai_reply_speech.dart`
- `mobile_app/test/domain/intent_resolver_test.dart`
- `mobile_app/test/domain/tts_echo_guard_test.dart`
- `mobile_app/test/features/assistant/localized_smart_ai_reply_speech_test.dart`
- `mobile_app/test/features/assistant/smart_ai_foreground_controls_test.dart`

## Artifacts

[Phone-signed release APK](../deliverables/AI-Blind-Assistant-1.4.16-vision-ai-commands.apk)
uses the predecessor's existing development certificate for an in-place release-mode
update. It contains no DEBUGGABLE flag; source signing configuration is unchanged.
The independent project-signed release remains in Flutter's build output.

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Phone delivery and installed APK | 126,355,367 | `1bc10e550d14a475ac69a48f2b323573a43c085d36d2ac23ee110f1f05d7fda3` |
| Project-signed Flutter release | 126,310,220 | `69661e23eff71b2fd4a63b8e698964c94a4d7403b1695068faed26b5bd3e546d` |

Exact next action: while the phone is unlocked and Smart AI is open, say can you
please go back without holding the circle and confirm speech plus navigation.
Then test Listen Vision AI → open about page / open setting / go home. For paused
speech, pause an existing answer or the local Hear how to use Smart AI guide,
wait two seconds after it stops (speaker echo guard), then say go back. The guide
uses no provider. Test connect to Raspberry Pi and start Mobile Mode for truthful
progress/results when their hardware is available. Keep ISSUE-083 open until real
voice/output/TalkBack results are recorded. No new paid test is necessary.

Git-style summary: `feat(voice): announce local action progress and route commands
by visible screen`; preserve current dirty branch, no commit/push. No new folders,
screens or domain types; Riverpod and central routes retained. Core model/camera/
shared speech implementation, all backend/Pi sources, dependencies/signing/version
source files, AGENTS.md and 31 Stitch references deliberately unchanged. Deferred:
physical accents/noise/TalkBack, cue perception and stable Pi power; no new always-on
background microphone or AI-executed commands.

## Owner-directed Pixel 9 Pro installation — 2026-10-21

The owner redirected deployment to a newly connected Google Pixel 9 Pro. Explicit
ADB device selection targeted only that phone. Its reported platform is Android
17/API 37, arm64-v8a, unlocked; no copy of this package was installed previously.
No source, APK rebuild, signing change, uninstall, data clear, credential transfer
or paid/provider request was needed. The same verified delivery artifact was used.

| Command/check | Actual result |
|---|---|
| Targeted `adb devices -l`, `getprop`, package existence and lock check | Pixel 9 Pro authorized/connected; Android 17/API 37, ARM64; fresh installation, unlocked |
| Delivery SHA-256, SDK 36 `apksigner verify --verbose --print-certs`, `zipalign -c -P 16 4` | Exact delivery hash above; signature valid (v2/v3), alignment passes |
| Targeted `adb install --no-incremental -r deliverables/AI-Blind-Assistant-1.4.16-vision-ai-commands.apk` | Exit 0; Performing Streamed Install; Success |
| Pull installed base APK and package metadata | SHA-256 equals delivery; 1.4.16/code 4056, DEBUGGABLE absent; firstInstallTime/lastUpdateTime both **2026-10-21 14:30:57** (fresh install) |
| Targeted `adb shell am start -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok/COLD; ended at Android permission activity, TotalTime 362 ms / WaitTime 364 ms; this is **not** app-only cold-launch latency |
| Later app/activity, permissions and current-PID crash-buffer checks | MainActivity focused, device unlocked, app alive, zero Java/native fatal markers; microphone permission granted by user, camera permission ungranted |
| Local TTS-service query | Google TTS service available; unset default-synth setting alone does not establish a missing engine/voice |

App accessibility nodes are present, but expected static text labels were not
exposed by this inspection; no click or acoustic acceptance is inferred. No raw
hierarchy/screenshot, user speech, private content or credentials were retained.
The agent did not grant runtime permissions or modify phone settings. The earlier
646 Flutter/22 Android test results and debug/release builds remain applicable to
the unchanged artifact; they were not rerun for this installation-only follow-up.

This fresh phone does not inherit the other phone's Keystore keys, provider opt-in,
settings or Pi pairing. Exact next action: open the app on the Pixel, complete its
personal Smart AI setup through Connection settings when cloud conversation is
wanted, then verify direct go back on configured Smart AI and the local listening
cue. Use the existing setup form; do not embed keys or copy encrypted app data
between Keystores. Camera access can be granted when starting Mobile Mode.
Physical voice/noise/TTS/haptic/Pi acceptance remains open on this new device.
