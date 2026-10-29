# Reader voice interruption verification

Date: 2026-10-15. Module 67. Software verified; release phone update and startup verified.

The owner requested clear foreground voice controls while a scanned document
is being read, with protection against the document triggering those controls.
Existing uncommitted work was preserved using a 477-file SHA-256 baseline.

## Changes and boundaries

- Reader playback opens contextual commands when hands-free recognition is
  already enabled and permitted. Pause/stop leave commands available for resume;
  explicit goodbye remains effective until another wake or new reader entry.
- Continuous speech can prevent Vosk's silence-based final result. In reader
  playback only, a stable multiword partial can propose a command after 250 ms.
  This is a proposal threshold, not measured capture-to-action latency.
- Dart accepts only strong registered reversible reader intents, rejects
  current/recent spoken-text echo, and checks current foreground context and
  session. Native acceptance atomically consumes a current candidate within
  1.5 seconds and pauses its decoder. Old, changed, duplicate or reset candidates
  cannot be claimed. Other partials cannot execute navigation, capture or tools.
- Echo checks cover whole-token phrases across the active sentence, Vosk
  unknown markers, spelling output and up to four recent utterances for 1.5
  seconds. Utterance identity and generation both protect callback ownership.
  Branded wake phrases printed in a document receive echo protection too.
- Supported device AEC/noise suppression/gain control attach before capture.
  This uses the existing microphone, bundled recognizer and speech owner.
- Each speech turn owns its awaited native result and cancellation signal.
  Late global cancel/completion callbacks cannot finish replacement speech;
  progress must match the active text. Completion mode and handlers are
  reclaimed for every turn, including after Mobile feedback used the engine.
- Read Again/capture have no competing command-result utterance. Stop Reading
  does not initialize an unused Mobile alert engine. Speed changes restart the
  selected line at its new rate; spelling releases the old pending reader loop.

Text matching supplements acoustic cancellation; it does not identify speakers.
If a printed sentence contains the same command the user says, rejection is
conservative. Use the branded wake phrase, wait for reading to stop and the
acknowledgement, then issue the command, or use the reader's touch controls.
Microphone audio, documents and partial transcripts are not recorded/uploaded
or logged by these changes. Real speaker overlap, accents/noise, volume and
device AEC still need the physical acceptance matrix below.

## Exact software verification

Flutter commands run in `mobile_app/`; native command in `mobile_app/android/`.

| Command/check | Observed result |
|---|---|
| `dart format lib test integration_test` | Exit 0; final formatting run 240 files, 1 changed; `dart format --output=none --set-exit-if-changed lib test integration_test` then passed, 240 files, 0 changed (0.39 s) |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found; final run 2.4 s |
| Targeted tests: accessible player, echo guard, reader policy, reader widget and speech output | Exit 0; 70 passed in 3 s; synthetic document/audio events, not acoustic trials |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python PYTHONPATH=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/src flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **459 passed**, 0 failed/skipped; final run 14 s, real Python Pi simulator enabled |
| `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --rerun --offline --console=plain` | Exit 0; BUILD SUCCESSFUL, final run 7 s; fresh app XML: **13 tests**, 0 failures/errors/skips |
| `flutter --no-version-check build apk --debug --split-per-abi --target-platform android-arm64` | Exit 0; assembleDebug 8.6 s; debug APK not installed |
| `flutter --no-version-check build apk --release --split-per-abi --target-platform android-arm64` | Exit 0; assembleRelease 24.9 s; signed release APK |
| SDK 36 `apksigner verify --verbose --print-certs`, `zipalign -c -P 16 4`, `aapt dump badging` | All exit 0; valid project release signer, alignment, 1.4.4/code 4044, non-debuggable |
| Release ZIP/AOT inspection | `libapp.so` present, debug kernel absent; all three new bridge method names present in AOT and native ReaderBargeInGate present in DEX |

No backend/Pi source or dependencies changed. Their full Python suites and the
existing dependency-blocked aggregate native/lint checks were not rerun.
The Pi simulator remains part of the full Flutter evidence. Existing legacy
Kotlin/Gradle migration warnings remain; no dependency upgrade was introduced.

Intermediate checks found an optional-interface promotion error and style
infos, then passed after correction. A first test invocation used the wrong
working-directory path for the new test file; after creation it ran normally.
The first widget run exposed that Stop Reading instantiated an unused real
Mobile alert service in its cleanup path. That was corrected in the executor;
all tests now pass without deleting or bypassing a test.

## Release and deployment

| Property | Value |
|---|---|
| APK | `mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Version | 1.4.4+2044; ARM64 split code 4044 |
| Mode | Flutter release/AOT, non-debuggable |
| Bytes | 125,916,832 |
| SHA-256 | `88b9390a4b9e1256caf1cac9f0dd3d8e3b39cb5b4b1b4ef33db282bf51dec91d` |
| Public signer SHA-256 | `f98b86d6b1fda2b9229b1960603178e11fb91c109d6ab457cc55d291c05f33f8` |
| Phone target | Previously authorized TECNO LE6/API 30, `192.168.10.36:36063` |
| Before update | Version 1.4.3/code 4043, installed hash matches the previous project release |
| Installation | `adb -s 192.168.10.36:36063 install --no-incremental -r <apk>`: exit 0, Success; installed 1.4.4/code 4044, matching SHA-256, DEBUGGABLE absent; first-install timestamp preserved |
| Cold startup | `adb -s 192.168.10.36:36063 shell am start -W -n com.example.ai_blind_assistant/.MainActivity` after force-stop: exit 0, Status ok, TotalTime 5090 ms / WaitTime 5107 ms; process alive/resumed; zero current-process fatal markers |

Signing configuration, model assets, original deliverables and Stitch sources
are preserved. The existing laptop launch service and Ollama remain healthy:
localhost and private-LAN port 8765 both returned status ok/protocol 1,
Ollama llama3.2:3b available, AI available; Gemini not configured. Phone backend
pairing remains unconfirmed because its UI setup was interrupted before an owner
code was generated; the emulator credential was not rotated. Offline reader
commands do not depend on it. The emulator remains on release 1.4.3. No uninstall,
data clear, re-sign or automatic permission grant occurred in this update.

## Physical acceptance to record

1. With hands-free enabled, scan a harmless printed page using the phone. While
   it reads, say Stop Reading and Pause Reading; verify prompt silence and that
   Resume Reading works afterward. Repeat while spelling and after a rescan.
2. During speech, use Read Again, Previous/Next/First/Last Line, Go to Line Five,
   Spell Out and slow/normal/fast profiles. Verify selection, no duplicate
   command narration, audible rate change and no skipped/stuck reader loop.
3. Read a page containing those commands and a branded wake phrase. Without
   speaking, verify that none executes. Include commands at sentence ends,
   punctuation, a long sentence and consecutive short sentences.
4. Repeat with quiet/loud media volume, usual holding distance, different
   speakers/accents, background noise and supported headphones. If acoustic
   overlap is missed, record device/AEC/volume and the phrase; do not log audio.
5. Say Goodbye during reading, then verify bare controls do not reactivate the
   session. Wake deliberately and control again. Background/lock must suspend
   listening; queued proposals must not execute after returning or changing page.
6. Check TalkBack, large text, microphone revocation and physical cancellation.

## Required completion record

1. Module result: software verified; physical acoustic acceptance remains open.
2. Workspace before work: existing dirty project preserved; 477-file baseline.
3. Architecture: feature layers retained; optional reader-recognition capability.
4. State management: existing Riverpod providers and voice kernel.
5. Routing: existing named routes, unchanged.
6. Folder structure: existing folders only.
7. Screens: none created; existing Scanner coordinates reader playback state.
8. Domain types: ReaderBargeInRecognition, ReaderVoiceCommandPolicy and typed candidate metadata.
9. Tests: new native gate, real reader widget, reader policy and speech-owner regressions; existing echo/bridge tests extended.
10. Markdown created: this verification report.
11. Markdown updated: living module/status/handoff, evidence, guides and ADR-067.
12. Requirements: FR-013/014/015, NFR-OFFLINE-002, NFR-REL-001, NFR-MAINT-002; no physical gate promoted.
13. Commands executed: exact software table and deployment record above.
14. Exact results: 459 Flutter/13 native passes, clean analysis, successful builds.
15. Android build: debug and signed release pass; phone installation/checksum/cold startup verified.
16. Files added: reader capability/policy/native gate and four test files, this report.
17. Files modified: reader/player/kernel/recognizer/speech adapter, version and living docs.
18. Deliberately unchanged: backend/Pi implementation, models, original deliverables, signing identity.
19. Stitch: all 31 baseline files match their SHA-256; no missing baseline files.
20. Known issues: real loudspeaker/AEC and existing hardware/native-lint gates remain open.
21. Deferred: acoustic tuning beyond observed physical evidence; broader recognizer/tool behavior.
22. Exact next action: run the physical reader voice/echo matrix above on the updated phone.
23. Git-style summary: `fix(reader): handle guarded voice interruption during document speech`.

## Final file inventory

Compared with the 477-file pre-change snapshot: **27 existing files modified, 8 files added, 0 missing**. All 31 Stitch file hashes match. All 75 relative Markdown links in the changed
documents resolve; `git diff --check` exited 0. No commit or push.

Modified:

- `docs/AGENT_HANDOFF.md`
- `docs/BUILD_AND_RUN.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_MODULE.md`
- `docs/DOCUMENT_SCANNER_GUIDE.md`
- `docs/INDEX.md`
- `docs/KNOWN_ISSUES.md`
- `docs/OFFLINE_VISION_ASSISTANT_GUIDE.md`
- `docs/PROJECT_STATUS.md`
- `docs/TESTING.md`
- `docs/architecture.md`
- `docs/assistant.md`
- `docs/decision-log.md`
- `docs/requirements-traceability.md`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`
- `mobile_app/lib/app/voice_kernel/command_authorizer.dart`
- `mobile_app/lib/app/voice_kernel/command_executor.dart`
- `mobile_app/lib/app/voice_kernel/vision_voice_kernel_v3.dart`
- `mobile_app/lib/domain/services/accessible_text_player.dart`
- `mobile_app/lib/domain/services/on_device_speech_recognition_service.dart`
- `mobile_app/lib/domain/services/tts_echo_guard.dart`
- `mobile_app/lib/features/ocr_scanner/presentation/ocr_scanner_screen.dart`
- `mobile_app/lib/infrastructure/assistant/android_on_device_speech_recognition_service.dart`
- `mobile_app/lib/infrastructure/assistant/flutter_tts_speech_output_service.dart`
- `mobile_app/pubspec.yaml`
- `mobile_app/test/domain/tts_echo_guard_test.dart`
- `mobile_app/test/features/assistant/android_on_device_speech_recognition_service_test.dart`

Added:

- `docs/READER_VOICE_VERIFICATION_2026-10-15.md`
- `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/ReaderBargeInGate.kt`
- `mobile_app/android/app/src/test/kotlin/com/example/ai_blind_assistant/ReaderBargeInGateTest.kt`
- `mobile_app/lib/domain/services/reader_barge_in_recognition.dart`
- `mobile_app/lib/domain/services/reader_voice_command_policy.dart`
- `mobile_app/test/domain/reader_voice_command_policy_test.dart`
- `mobile_app/test/features/assistant/reader_speech_output_test.dart`
- `mobile_app/test/features/ocr_scanner/scanner_reader_voice_test.dart`

## Rescan framing follow-up

The owner confirmed that reader control works well, then requested time to aim
following “scan again” / “restart scanner”. This follow-up changes only the
rescan trigger from immediate capture to the existing Scan Another Page reset
path, and corrects the action metadata. It stops old reading, clears the page,
reopens live framing and waits without a timer. A later explicit “scan document”
or Scan button captures and starts OCR/reading. Reader interruption and echo
protection are retained. ADR-067's addendum supersedes ADR-066's immediate
rescan decision. No camera ownership or recognition architecture change.

Before work: 485-file SHA-256 snapshot of the already dirty workspace. No new
folders, screens, domain types, dependencies or source files. Existing rescan
widget tests were updated for the newly requested behavior rather than removed:
both aliases enter framing, wait ten simulated seconds with zero captures/OCR,
allow repeated restart, then explicitly scan, read new text, reject overlapping
capture requests and delete the synthetic temporary photo.

| Command | Final result |
|---|---|
| `dart format lib/app/voice_kernel/command_executor.dart lib/domain/services/voice_action_registry.dart test/features/ocr_scanner/scanner_voice_rescan_test.dart` | Exit 0; 3 files, 2 formatted |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 240 files, 0 changed, 0.39 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, final run 2.5 s |
| `flutter --no-version-check test --no-pub test/features/ocr_scanner/scanner_voice_rescan_test.dart -r expanded` | Exit 0; 2 passed |
| Full Flutter command from the software table above, with real Python simulator | Exit 0; 459 passed, 0 failed/skipped; 14 s |
| ARM64 debug build command from the software table above | Exit 0; assembleDebug 10.2 s; not installed |
| ARM64 release build command from the software table above | Exit 0; assembleRelease 22.6 s; signed release 1.4.5+2045, ARM64 code 4045 |
| Release verification | SDK 36 apksigner/zipalign/aapt all exit 0; same project signer, aligned, non-debuggable, AOT present, debug kernel absent |
| Phone release update | `adb -s 192.168.10.36:36063 install --no-incremental -r <apk>` exited 0, Success; installed 1.4.5/code 4045/hash match, DEBUGGABLE absent, first-install time preserved |
| Phone startup | `am start -W -n com.example.ai_blind_assistant/.MainActivity` exited 0, Status ok; final TotalTime 3391 ms / WaitTime 3397 ms, process alive/resumed, no permission prompt; zero current-process fatal markers |

The first full run found that the synthetic camera had not advertised streaming
support, so the new framing-stream assertion failed; early failure also restored
the platform before widget disposal. The fixture now advertises its supported
preview stream and disposes the widget before restoring the platform. The two
regressions and final full suite pass. No production fallback, test deletion or
recognizer weakening was used. No native/backend/Pi implementation changed;
those suites were not rerun for this Dart-only follow-up. Device-native
recognition and actual repositioning remain physical checks.

The first post-update launch returned Status ok but resumed state was not
confirmed while the phone became inactive. Waking and launching again returned
Status ok and a resumed app. No uninstall, data clear, re-sign or automatic
permission grant was used. No physical OCR/voice accuracy claim follows from
installation or synthetic transcripts.

Exact next action: verify scan again → aim at the next page → explicit Scan on
the updated phone, with no photo before that action.

Follow-up artifact: `mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`,
125,916,832 bytes, SHA-256
`d7d914f2a295fd6e5813c3a9a651fa48f5ce8937e50986f95444c3e1ccdbc0fd`.
Public signer remains `f98b86d6b1fda2b9229b1960603178e11fb91c109d6ab457cc55d291c05f33f8`.
The earlier release table records the original 1.4.4 phase, not this follow-up.

Follow-up preservation: 19 existing files modified, no added/missing files,
all 31 Stitch hashes unchanged. All 81 local Markdown links in those documents
resolve and `git diff --check` exits 0. Existing unrelated edits are preserved.
Exact modified files:

- `docs/AGENT_HANDOFF.md`
- `docs/BUILD_AND_RUN.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_MODULE.md`
- `docs/DOCUMENT_SCANNER_GUIDE.md`
- `docs/INDEX.md`
- `docs/KNOWN_ISSUES.md`
- `docs/OFFLINE_VISION_ASSISTANT_GUIDE.md`
- `docs/PROJECT_STATUS.md`
- `docs/READER_VOICE_VERIFICATION_2026-10-15.md`
- `docs/TESTING.md`
- `docs/architecture.md`
- `docs/assistant.md`
- `docs/decision-log.md`
- `docs/requirements-traceability.md`
- `mobile_app/lib/app/voice_kernel/command_executor.dart`
- `mobile_app/lib/domain/services/voice_action_registry.dart`
- `mobile_app/pubspec.yaml`
- `mobile_app/test/features/ocr_scanner/scanner_voice_rescan_test.dart`

Follow-up summary: `fix(scanner): return voice rescan to framing before capture`.
No commit or push.

## Emulator launch follow-up

On the owner's later “run on emulator” request, started the existing
`medium_phone` AVD (emulator-5554); boot completed. The existing verified signed
release APK was installed with `adb -s emulator-5554 install --no-incremental -r
<apk>`: exit 0, Success. Version 1.4.5/code 4045, installed SHA-256 matching the
follow-up artifact, DEBUGGABLE absent. Direct launch after force-stop via
`am start -W -n com.example.ai_blind_assistant/.MainActivity` exited 0, Status ok,
TotalTime 715 ms / WaitTime 719 ms. App process alive/resumed, UI available,
no permission dialog or welcome Continue, zero current-process fatal markers.
Left the release app and emulator running. No conversation/document was sent,
no phone action or permission grant occurred, and no source change, rebuild or
suite rerun was needed for this runtime-only follow-up. This replaces the
emulator's earlier 1.4.3 installation; hardware/voice/OCR acceptance is unchanged.

## Phone Smart AI connection — verified runtime follow-up

The owner reported Smart AI unavailable on the physical phone and asked whether
the laptop backend was running. The existing launchd backend was already
running; localhost and 192.168.10.5:8765 /health both returned status ok,
protocol 1, Ollama/AI available, local llama3.2:3b, Gemini not configured.
The phone showed the unpaired banner and its connection form still selected
the older 10.141.17.235 default. Through the existing app form, changed host to
192.168.10.5 and port 8765, generated a private owner one-time code and completed
pairing. “Paired successfully!” was observed, then Smart AI reported the laptop
reachable. This replaces the earlier emulator backend credential; do not pair
the emulator again without the owner's intended target because pairing rotates
the single backend credential.

With the input empty, sent only the synthetic “Reply with the single word
ready.” request. After returning the backgrounded phone app to the foreground,
the actual Assistant reply containing “ready” was confirmed separately from its
Ready status; no timeout was visible and the backend was reachable. No document,
audio, personal data, code or bearer token was logged. No app/backend source,
APK, dependency, signing, database schema or authentication bypass changed.
No build/test-suite rerun was needed for this runtime-only pairing repair.
The phone release remains 1.4.5; the backend and Ollama remain running.

Exact next action: use Smart AI on the phone with the laptop awake and both on
the same private LAN. Actual microphone transcription, speaker audibility,
Gemini and outage/reconnect acceptance remain separate tests.

The prior emulator performance setup was interrupted: a dedicated API 36 ARM64
AVD was created with 4 cores, 4096 MB, 720x1600 and host graphics. Host renderer
Apple M1 Max was confirmed; release hash/non-debuggable flags matched and
Home → Settings → Home passed after an 889 ms launch. The emulator subsequently
closed; a snapshot-disabled restart also exited before this phone follow-up.
No emulator is currently claimed running and no smoothness benchmark was
established. The phone task took priority; no automatic restart loop was added.
