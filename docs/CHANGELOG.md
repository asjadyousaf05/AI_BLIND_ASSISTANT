# Changelog

## 2026-08-16 — Professional Voice Assistant Audio Isolation & "Stop Detection" Priority (v1.4.0+2039)

- **Detection Audio Isolation & Silent Gate**: Voice assistant enters Command-Only Mode while camera detection is running; silently ignores non-command ambient noise and TTS echoes without conversational AI chatter or *"Sorry, I didn't recognize that command"* audio collisions.
- **Priority "Stop Detection" Execution**: Prioritized *"stop detection"*, *"stop camera"*, *"stop vision"*, *"stop model"*, *"pause detection"*, and contextual *"stop"* to cleanly stop camera inference, halt alerts, pop screen back to Home, and speak *"Detection stopped."*
- **Wake-Word Vocal Prompt Suppression**: Suppressed vocal wake prompts during active vision sessions to prevent audio overlap.
- **Verification**: 271 Flutter tests passed, 0 analyzer issues, release APK built & installed on TECNO BG6.

## 2026-08-16 — Dedicated Household Object Detection Model & Dual Interpreter Pipeline (v1.4.0+2038)

- **Dedicated Household Model**: Bundled and deployed `household_yolov8n_float32.tflite` (13.5MB LiteRT OpenImages V7 neural network covering 601 household & domestic categories) alongside `openimages_labels.txt` and `household_model_metadata.json`.
- **Concurrent Dual-Model Native Inference**: Upgraded Kotlin `InferenceHandler.kt` to run both COCO-80 and OpenImages-601 interpreters concurrently on a shared preprocessed frame buffer.
- **Multi-Model Detection Fusion**: Integrated `MultiModelFusionService` Weighted Box Fusion (WBF) and `HouseholdDetectionEngine` to merge domestic predictions into a unified, accurate object stream.
- **Verification**: 266 Flutter tests passed, 64 backend tests passed, 0 analyzer issues, release APK built & installed on TECNO BG6.

## 2026-08-16 — Multi-Model Household & Domestic Vision Architecture (v1.4.0+2037)

- **Multi-Model Detection Fusion**: Implemented `MultiModelFusionService` with Weighted Box Fusion
  (WBF) and multi-model Non-Maximum Suppression to blend general YOLO and household detector streams.
- **Household Detection Engine**: Added `HouseholdDetectionEngine` with domestic object categories
  (furniture, appliances, kitchenware, electronics, personal items, hazards) and indoor sensitivity priors.
- **Environmental Scene Modes & Voice Commands**: Added `DetectionEnvironmentMode` with voice controls
  (*"indoor mode"*, *"home mode"*, *"outdoor mode"*).
- **Verification**: 266 Flutter tests passed, 64 backend tests passed, release APK built & installed on device.

## 2026-08-16 — Major Voice Engine & Accessible Reading Player Upgrade (v1.4.0+2036)

- **Accessible Text Player & Sentence Navigation**: Added `AccessibleTextPlayer` enabling sentence-level
  indexing, hands-free pausing, resuming, stepping forward/backward (*"previous line"*, *"next sentence"*),
  repeating, restarting from the beginning, and letter-by-letter spelling.
- **Adaptive Reading Profiles**: Implemented Study/Learning Mode (0.35x + inter-sentence pauses),
  Normal Mode (0.50x), Skim/Fast Mode (0.75x), and Spell Mode.
- **TalkBack On-Screen Toolbar**: Added tactile buttons for Previous, Play/Pause, Next, Repeat, Spell,
  and quick speed pills (`Study 0.35x`, `Normal 0.5x`, `Fast 0.75x`) alongside live sentence indicators.
- **Verification**: 254 Flutter tests passed, 64 backend tests passed, release APK built & installed on device.

## 2026-08-16 — Multi-Tier Immediate Stop Audio Interruption (v1.4.0+2034)

- **Comprehensive Stop Recognition**: Expanded Kotlin native handler and Dart controller to
  recognize any variation of *"stop"*, *"stop audio"*, *"stop speaking"*, *"stop voice"*,
  *"stop it"*, *"quiet"*, *"silence"*, *"shut up"*, *"mute"*, *"pause"*, *"hush"*, *"shh"*,
  or *"cancel"*.
- **Universal Multi-Channel Cutoff**: Immediately halts assistant TTS, Document Scanner OCR reading,
  and obstacle alert audio streams simultaneously.
- **Verification**: 235 Flutter tests passed, 0 analyzer issues, release APK built.

## 2026-08-16 — P1 Vision, Spatial Audio & Document Framing Guidance (v1.4.0+2033)

- **Auto-Flashlight & Luminance Sensing**: Camera frames sample ambient luminance; auto-activates
  torch in dark scenes with spoken notifications. Toggable via voice (*"turn on flashlight"*).
- **Spatial 3D Audio Panning**: Obstacle alerts pan across stereo channels in earphones (-0.85
  to +0.85) reflecting the actual horizontal direction of the detected obstacle.
- **Real-Time Document Framing Guidance**: 3x3 contrast gradient analyzer provides real-time
  spoken alignment cues (*"Move phone higher"*, *"Hold steady, document aligned"*) with haptics.
- **Verification**: 235 Flutter tests passed, 64 backend tests passed, release APK installed on device.

## 2026-08-16 — Two-Step Document Scan Flow (Preparation Prompt vs Voice Capture) (v1.4.0+2032)

- **Guaranteed Voice-Driven Capture**: When you say *"scan another"*, *"scan another page"*,
  or *"rescan"*, the app sets the scanner to ready, announces *"Ready to scan. Point your camera at the document and say scan"*, and waits without taking a photo prematurely.
- **Explicit Trigger on "Scan"**: The camera takes the picture and reads the text only after you
  say *"scan"*, *"take picture"*, *"take picture and scan"*, or *"capture"*.
- **Verification**: 228 Flutter tests passed, 0 analyzer issues, release APK installed on device.

## 2026-08-16 — Instant Image Capture on Document Rescan (v1.4.0+2031)

- **Fresh Photo Capture on Rescan**: Fixed document scanner so saying *"scan again"*, *"rescan"*,
  or *"try again"* directly stops previous speech, triggers the camera to take a fresh picture,
  and extracts/reads the recognized text.
- **Verification**: 228 Flutter tests passed, 0 analyzer issues, release APK installed on device.

## 2026-08-16 — Mandatory Audio Feedback Enforcement for Detection Modes (v1.4.0+2030)

- **Mandatory Spoken Audio for Safety**: Because real-time obstacle announcements are essential
  for blind navigation, starting Mobile Mode or Wearable Mode now automatically ensures
  spoken audio output is active (`FeedbackMode.audioAndVibration`), preventing silent detection sessions.
- **Verification**: 228 Flutter tests passed, 0 analyzer issues, release APK installed on device.

## 2026-08-16 — Screen-Off & Background Wake-Word Assistant (v1.4.0+2029)

- **Screen-Off Voice Activation**: Maintained hands-free wake-word recognition (*"Hey Vision AI"*)
  active when the phone display is turned off or locked, enabling pocket and hands-free usage for blind users.
- **Lifecycle Adaptation**: Updated Flutter lifecycle observers so only complete process
  detachment stops the offline recognizer; screen sleep (`inactive`/`paused`) keeps the recognizer and partial wake-lock running smoothly.
- **Verification**: 228 Flutter tests passed, 0 analyzer issues, release APK installed on device.

## 2026-08-16 — System-Wide Conditional Auto-Resolution & Startup Self-Healing (v1.4.0+2028)

- **Self-Healing Feedback Settings**: Automatically synchronizes `vibrationEnabled` when
  vibration-only mode is selected via voice or UI, and automatically auto-resolves any
  contradictory feedback settings prior to Mobile Mode or Wearable Mode startup.
- **Accurate Startup Reporting**: Assistant verifies the actual startup status of Mobile Mode
  and Wearable Mode, reporting actionable guidance instead of premature success messages.
- **Camera Pipeline Conflict Protection**: Automatically releases the camera hardware from
  the OCR Scanner before initializing Mobile Mode obstacle detection.
- **Verification**: 227 Flutter tests, 64 backend tests, 14 Pi tests, and release APK built.















## 2026-08-14 - Foreground “Hey Vision AI” Assistant and Release 1.3.3

- Added a foreground hands-free cycle: the already-open app listens locally
  for the exact branded phrase “Hey Vision AI”, gives a spoken acknowledgement,
  accepts the following command, speaks the real result, and returns
  to ready state. Spoken confirm/cancel completes protected actions without
  touch.
- Bundled the official Vosk small English Android model so the target TECNO no
  longer depends on its missing speech-recognition service. Manual voice now
  prefers the dedicated Android service and falls back to Vosk; the ordinary
  possibly remote recognizer is never used.
- Added strict wake matching with `AI`/`A I`/`eye` ASR tolerance, generic-
  assistant false-wake rejection, buffered-audio reset after TTS, serialized
  lifecycle recovery, foreground screen-awake behavior, and an accessible
  hands-free setting/status.
- Fixed the physical-device no-response case by checking settled partial Vosk
  hypotheses, using a seven-entry focused wake grammar with `[unk]`, restoring
  the default graph for commands, tolerating bounded accent/decoder variants,
  and suppressing duplicate final callbacks so the wake phrase cannot become
  its own command.
- Fixed the actual blank-transcript defect found during the second physical
  retest: Vosk n-best mode moved final text into `alternatives[]` while the
  handler read only top-level `text`. Release 1.3.3 disables n-best output,
  defensively accepts either JSON shape, and adds a native contract regression.
- Added offline spoken greetings, Vision AI identity, and “what can you do”
  help. Updated the Gemini/Ollama system persona for short, natural TTS replies;
  deterministic app controls still bypass both providers.
- Defaulted the current optional backend to
  `Asjads-MacBook-Pro.local:8765` and registered its Ollama-backed FastAPI
  process as a macOS per-user launch service. One-time secure pairing remains
  mandatory; Gemini remains optional and unconfigured on this host.
- Verified clean formatting/analyzer, 202 Flutter tests with one gated Pi skip,
  5 native wake tests, Ruff, 49 backend tests, release Kotlin compilation,
  signed ARM64 build, USB update, and an active unsilenced 16 kHz capture client.
- Delivered `1.3.3`/`2011`, 97,185,174 bytes, zipaligned and v2-signed, SHA-256
  `9430d92b35dca391b24b29521a30e1c294c0578498fa3619869827185713c8ae`.
  TTS and the deterministic offline reply were verified physically; unlocked
  real-speaker wake/TalkBack/accent/noise/battery acceptance remains open.

## 2026-08-14 - Module 25: Phone-Local Voice Controls and Release 1.2.0

- Replaced the active phone-recorder/laptop-Whisper app-control path with
  Android 12+'s dedicated on-device speech recognizer. The app never falls back
  to the ordinary potentially remote recognizer.
- Routed in-memory spoken transcripts through the existing deterministic
  phone command parser before pairing or network checks. Sensitive actions
  still require explicit confirmation; only unmatched general-conversation
  text may use the optional Gemini/Ollama backend.
- Updated Assistant UI/privacy copy, Android package visibility, lifecycle
  cancellation, service abstractions, architecture/requirements decisions, and
  physical run guidance for the laptop-free voice boundary.
- Added native-channel and controller regressions for availability, transcript
  transport, unpaired app control, no backend fallback, and spoken sensitivity
  confirmation. Format checked 178 files, analyzer passed, and the full Flutter suite passed 195 tests
  with one environment-gated Pi test skipped.
- Built, zipaligned, v2-signature verified, and installed ARM64 `1.2.0`/`2006`
  over USB on the TECNO BG6 while preserving app data. The 45,536,704-byte APK
  SHA-256 is
  `05c237b092391d440a0363d86ccdcd373c6f7c10567b00888754f66fab719739`.
  The live app process has no app-scoped fatal/ANR; real speech acceptance is
  still open because the phone remained locked after installation.

## 2026-08-14 - Module 25 Refinement: Offline App Controls and Release 1.1.1

- Added a model-free, network-free Flutter command parser for typed settings,
  Mobile Mode, Raspberry Pi, assistant-status, time/date, and recent-detection
  requests. It runs before pairing/health checks and uses existing Riverpod
  controllers with confirmation for sensitive actions.
- Kept spoken app commands offline from AI providers: local Whisper supplies the
  transcript on the paired laptop and the deterministic backend matcher routes
  it before Gemini/Ollama. Added natural on/off phrases including “turn the
  mobile mode detection on.”
- Added deterministic on-phone tool-result wording, truthful unpaired UI copy,
  and explicit documentation that laptop-free voice is not yet claimed.
- Verified 189 Flutter tests plus one gated Pi skip, 49 backend tests with 29
  upstream warnings, clean analyzer/Dart formatting/Ruff, and rebuilt the signed
  ARM64 deliverable.
- Delivered `1.1.1`/`2005`, 45,602,192 bytes, zipaligned and v2-signed, with
  SHA-256 `199490b0f6b0b797735c56de0c8acd22c984e98885690ade1e5005a95083ded4`.
  Wireless ADB installation remains open because no device or mDNS service was
  visible.
- Subsequently installed the same checksummed APK over USB on a TECNO BG6
  (Android 13/API 33, ARM64), preserving existing data. Two direct cold launches
  passed in 709 ms and 591 ms. Real Mobile Mode displayed a live preview,
  Detecting, one detection and one alert; camera cleanup and app-scoped crash
  review passed. Assistant voice/TalkBack/Pi and sustained performance remain
  open physical gates.

## 2026-08-14 - Module 25: Hybrid Voice Assistant and Release 1.1.0

- Activated the owner-authorized assistant routes and Home entry.
- Implemented native push-to-talk recording, microphone permission, bounded
  cache files, secure Keystore credentials, domain TTS abstraction, and
  accessible confirmation.
- Wired real sensitivity, feedback/accessibility, Mobile Mode, and Raspberry Pi
  actions through the existing controllers with result verification.
- Added deterministic command routing, local Whisper transcription, optional
  Gemini-first reasoning, automatic Ollama fallback, strict tool validation,
  text-only Gemini requests, and privacy-minimized persistence.
- Verified 175 Flutter tests and 46 backend tests, plus live local
  Ollama/Whisper/health/pair/query behavior. Fresh Pi validation was blocked by
  PyPI DNS and live Gemini was blocked by the absence of a configured key.
- Built and verified ARM64 `1.1.0`/`2004`; the checksummed 45,536,660-byte APK
  is zipaligned and v2-signed. Wireless phone installation remains open because
  no ADB device is currently discoverable.

## 2026-08-14 - Module 24: Professional Audit and Release 1.0.2

### Added

- Added a bounded preference `TextScaler` that preserves Android's platform
  scaling curve, explicit heading levels, and Flutter Android checks for touch
  targets, labels and contrast.
- Added nonlinear-scaling, 2.0-text assistant layout and disabled-experiment
  route regressions.
- Added a research-backed professional audit and current Android 17 local-
  network migration note.

### Changed

- Corrected experimental assistant Mobile resume behavior and made missing
  microphone/recording MethodChannels fail truthfully instead of simulating
  success.
- Preserved the user-owned assistant/laptop source outside the production import
  graph; standard Home/routes cannot reach it, AOT inspection confirms it is
  absent from the release library, and microphone permission is not requested.
- Ignored experimental database/environment state, isolated backend test data,
  hardened diagnostics, added Ruff and formatted/linted its Python source.
- Applied compatible Flutter dependency upgrades and bumped the standard app to
  `1.0.2+3`.
- Replaced the signed ARM64 deliverable and checksum.

### Verification

- Flutter format check passed for 170 files; analyzer reported no issues; all
  171 Flutter tests passed.
- Pi format/Ruff/compile/shell checks and all 14 tests passed.
- Experimental backend format/Ruff/compile and all 26 tests passed with one
  upstream Starlette/httpx deprecation warning.
- A release attempt with `--no-pub` failed because a debug-generated registrant
  referenced dev-only `integration_test`; the documented release command ran
  Flutter preparation, excluded it correctly and passed. Fresh debug also passed.
- `deliverables/AI-Blind-Assistant.apk` is 45,339,240 bytes, zipaligned,
  v2-signed, ARM64, min SDK 24, target SDK 36, version `1.0.2`/split code `2003`,
  and SHA-256
  `95b6451e0fcd12b1bcceb9fccba17fe90e4b53cd1766dcbf1b8f6fa455c549af`.
- A late-connected ARM64 Android 13/API 33 phone passed final release install,
  1,479 ms cold start and real CameraX `Detecting`/clean-close smoke with no
  PID-scoped fatal log; the process was force-stopped afterward. Box quality,
  feedback, TalkBack, permission, offline, performance and all Pi gates remain
  open; no production-safety claim was made.

## 2026-08-09 - Mobile Camera Device Compatibility Fix

- Replaced the single opaque rear-camera initialization attempt with safe
  fallback across every Android-reported rear camera.
- Preserved bounded CameraX/Platform error codes and descriptions in the
  accessible error state and added runtime camera-error cleanup.
- Added three regression tests; analyzer and all 146 Flutter tests pass.
- Built signed ARM64 release `1.0.1`/`2002`, verified alignment/signature/assets,
  and replaced the deliverable. Physical diagnosis still requires ADB or the
  exact on-screen CameraX code from the phone.

## 2026-08-09 - Module 23: Integrated Product and Signed ARM64 Release

### Added

- Added app-level high-contrast, large-text, and reduced-motion behavior driven
  by the existing persisted settings.
- Added explicit Mobile pause/release, live Home assistance status/stop, and a
  real Wearable connection-error retry/recovery path.
- Added local ignored release-keystore generation, Gradle release signing, a
  release checklist, and final user-facing APK packaging.
- Added regression coverage for global accessibility settings, Mobile pause,
  Home controls, and current Wearable help content.

### Changed

- Replaced stale deferred/incomplete Raspberry Pi and feedback copy with
  truthful implemented states without redesigning the UI.
- Removed the invalid generated main-source plugin registrant so release builds
  use Flutter's variant-specific generated registration.
- Repaired the host's partial official NDK toolchain sufficiently for the
  targeted ARM64 release build; no host-specific path was committed.

### Verification

- Offline dependencies, formatting, and analysis passed; all 146 Flutter tests
  and all 14 Pi Python tests passed.
- ARM64 debug and locally release-signed APK builds passed.
- Release metadata, ZIP alignment, v2 signature, RSA-3072 certificate, bundled
  model assets, and SHA-256 were verified.
- No Android phone or authorized reachable Pi was available. Installation,
  launch, physical camera/audio/haptics/TalkBack, Pi deployment/NCNN, both
  OV5647 sessions, and real FPS/latency remain explicitly open.

## 2026-08-09 - Module 15: Authenticated Raspberry Pi Wearable Mode

### Added

- Added a strict shared protocol-v1 implementation, short-lived local pairing,
  per-phone revocable credentials, replay protection, signed envelopes,
  acknowledgements, stable errors, heartbeats, deduplication, and bounded retry.
- Added a production-style Pi 3B service with one loaded Open Images V7 NCNN
  detector, Picamera2 capture, a one-slot frame queue, settings persistence,
  bounded recovery, local speech ownership, health reporting, mDNS, and secure
  non-root systemd deployment.
- Added protocol/security/service/deployment Python tests, Flutter protocol,
  controller/accessibility tests, and a real cross-process simulated Pi test.
- Added approved NCNN artifact checksums and complete wearable deployment,
  protocol, security-boundary, troubleshooting, and physical-acceptance docs.

### Changed

- Connected the preserved Raspberry Pi screen to the existing Riverpod/domain
  architecture, Android NSD discovery, Keystore-backed credential storage, and
  one lifecycle-aware WebSocket repository/state machine.
- Reconciled previously incompatible Flutter/Python paths, service names,
  timestamps, pairing-code lengths, HMAC derivation, settings, telemetry, and
  Open Images V7 detection schemas.
- Preserved Mobile Mode as a separate camera/model/feedback pipeline. Closing
  the phone transport no longer stops active essential Pi-local assistance.

### Verification

- Python compile and Ruff checks passed; 14 Python tests passed.
- Dart formatting and Flutter analysis passed; all 141 Flutter tests passed.
- The cross-process simulator passed pair/authenticate/settings/start/detection,
  disconnect/reconnect, pause/resume/stop, revoke, and forget-device flow.
- Offline Flutter dependency resolution and ARM64 debug APK build passed.
- SSH hostname/TCP reachability was found initially, but key authentication was
  unavailable; the final probe no longer resolved the Pi. Actual deployment,
  two camera sessions, NCNN timing/FPS, and physical Android/TalkBack/WAN-off
  acceptance remain explicitly unverified.

## 2026-08-06 - Real YOLOv8n Mobile Mode Integration and Emulator Verification

### Added

- Bundled the official Ultralytics `v8.4.0` YOLOv8n COCO LiteRT model,
  80-class labels, and generated tensor/provenance metadata.
- Added pinned model-export dependencies and a reproducible official-source
  export/verification script with SHA-256, real tensor inspection, and warm-up.
- Added stride-aware camera plane types, tensor transform metadata, two-frame
  detection stability, typed assistance failure kinds, and focused tests.
- Added `docs/model-integration.md` with source, license, export, preprocessing,
  parsing, feedback, replacement, and physical acceptance instructions.

### Changed

- Reworked native Android inference to run model load/warm-up/preprocessing and
  one inference at a time on a background executor with reusable direct
  buffers, actual tensor metadata, rotation/mirroring, YUV420 stride handling,
  RGB-114 letterboxing, normalization, and CPU fallback.
- Reworked Dart inference/post-processing to validate model metadata, parse the
  actual YOLO output layout, apply sensitivity thresholds and per-class NMS,
  undo letterboxing, and align normalized boxes with the preview.
- Connected stable detections to relative risk, short direction phrases,
  per-class cooldown, duplicate/global-rate suppression, urgent interruption,
  and finite saved-mode speech/vibration output.
- Hardened camera/model/permission/error states, start/stop generation guards,
  lifecycle cleanup, explicit resume, stream state synchronization, and safe
  resource disposal.
- Updated stale Mobile Mode copy without redesigning the native Flutter UI.
- Upgraded the verified Android runtime to non-transitive LiteRT 2.1.5 and
  removed inherited microphone, storage, foreground-service, and network-state
  permissions.
- Reconciled architecture, model, pipeline, alert, build, test, traceability,
  known-issues, status, and handoff documents with the real implementation.

### Verification

- Export/tensor warm-up passed; final model is float32 NCHW `[1,3,320,320]`
  to float32 `[1,84,2100]`.
- Official bus reference image returned three people and one bus from both
  PyTorch and final LiteRT.
- Offline dependency resolution passed; format check passed; analyzer reported
  no issues; all 128 tests passed.
- ARM64 split debug APK built, is v2 signed, contains exact model assets, and
  installed/launched on an ARM64 API 37 emulator.
- Emulator reached Detecting, stopped/restarted, released camera on background,
  returned Paused, and reached Detecting in Android airplane mode.
- Release merged manifest passed and has no internet/network-state permission.
- Release APK remains blocked at native symbol stripping because the local NDK
  lacks `llvm-strip`.
- No physical Android phone was connected; real-camera, TTS/haptic, TalkBack,
  offline, performance, memory, battery, and thermal acceptance remains open.

## 2026-07-26 - Android ARM64 Debug Build Verification

### Changed

- Updated Flutter 3.44 semantic announcements to use the current view-aware API.
- Replaced relocated legacy TensorFlow Lite Android dependencies with
  `com.google.ai.edge.litert:litert:1.0.1`.
- Configured debug APK variants to retain native symbols when `llvm-strip` is
  unavailable.

### Verification

- ARM64 debug APK build passed.
- ARM64 split debug APK build passed and v2 signature verification passed.
- Test suite executed: 116 passed, 2 stale Module 4 assertions failed.
- Static analysis executed: 22 diagnostics.
- No Android device or AVD was available, so install/launch and TalkBack checks
  remain blocked.
- The TFLite model remains absent, so live inference is not runnable yet.

## 2026-07-26 - Module 14: Complete Mobile Mode Integration

### Added

- **Module 14**: Unified `AssistanceController` state machine replacing ad-hoc widget orchestration
- `MobileAssistanceState` enum with 10 states: idle, permissionRequired, initialisingCamera, loadingModel, ready, starting, active, paused, stopping, error
- `AssistanceSessionState` class with state + optional errorMessage
- `AssistanceDiagnostics` class tracking processedFrames, droppedFrames, averageInferenceMs
- Comprehensive integration test file with 20 test cases (UT-INT-001 to UT-INT-020) using fakes for all services
- Single-inference-at-a-time guard with frame drop counting in InferenceController
- `docs/performance-test-plan.md` — Performance testing procedures for Android device

### Changed

- **Rewrote** `MobileAssistanceScreen` to use `assistanceControllerProvider` instead of manual imperative orchestration
- **Modified** `CameraController` to not auto-resume on lifecycle resume; lifecycle ownership delegated to `AssistanceController`
- **Modified** `FeedbackAlertOrchestrator` to accept and respect `FeedbackMode` (audio/vibration/audioAndVibration) with try-catch for graceful degradation
- **Modified** `FeedbackController` to pass `feedbackMode` from settings and expose `updateSettings()` method
- **Modified** `InferenceController` to track processedFrames, droppedFrames, totalInferenceMs, and enforce single concurrent inference

### Test Files Created

- `test/features/integration/mobile_mode_integration_test.dart` (20 test cases)

### Known Limitations

- Tests created as deliverables but not executed due to sandbox constraints
- Android APK build blocked by missing Android SDK
- Validation commands skipped per user instruction

## 2026-07-26 - Modules 6-13: Mobile Assistance Pipeline

### Added

- **Module 6**: Camera permission MethodChannel handler, app lifecycle observer, permission providers, accessible permission UI
- **Module 7**: SharedPreferences settings repository with validation and corruption recovery, auto-save on change
- **Module 8**: Camera service with preview, frame throttling (200ms), lifecycle-aware providers, camera preview widget
- **Module 9**: COCO labels file, model metadata JSON, Python export script, model evaluation docs, ModelAssets constants
- **Module 10**: InferenceService interface, TFLite MethodChannel service, native Kotlin InferenceHandler with YUV→RGB→float32 preprocessing
- **Module 11**: BoundingBox entity with IoU, DetectionResult entity, YoloPostProcessor with NMS and confidence filtering
- **Module 12**: ScreenPosition, ProximityLevel, RiskLevel enums, ObstacleAlert entity, ObstacleRiskAssessor with position/proximity/risk classification
- **Module 13**: TTS service (flutter_tts), vibration service (vibration package), FeedbackAlertOrchestrator with cooldowns and priority interruption

### Changed

- Updated `pubspec.yaml` with shared_preferences, camera, flutter_tts, vibration dependencies
- Updated `build.gradle.kts` with TFLite Gradle dependencies and aaptOptions
- Updated `AndroidManifest.xml` with CAMERA and VIBRATE permissions
- Updated `MainActivity.kt` with permission and inference MethodChannels
- Updated `AppSettings` with vibration, accessibility fields
- Updated `AppSettingsController` with persistence, new settings methods
- Updated `bootstrap.dart` to use ProviderContainer with early settings load
- Updated `PermissionsScreen` to request real permissions
- Updated `SettingsScreen` with vibration, cooldown, accessibility controls
- Updated `MobileAssistanceScreen` to integrate full pipeline (camera → inference → detection → risk → feedback)

### Test Files Created

- `test/features/permissions/permission_test.dart` (12 test cases)
- `test/features/settings/settings_persistence_test.dart` (5 test cases)
- `test/features/camera/camera_pipeline_test.dart` (6 test cases)
- `test/features/inference/inference_test.dart` (5 test cases)
- `test/features/detection/detection_post_processing_test.dart` (14 test cases)
- `test/features/detection/risk_assessment_test.dart` (10 test cases)
- `test/features/feedback/alert_orchestrator_test.dart` (10 test cases)

### Known Limitations

- Tests created as deliverables but not executed due to sandbox constraints
- TFLite model file must be generated by user via `scripts/export_yolov8n.py`
- Android APK build blocked by missing Android SDK
- Validation commands skipped per user instruction

## 2026-07-19 - Module 4: Native Flutter UI Migration from Stitch Designs

### Added

- Added reusable native Flutter UI components:
  - `AppScreenScaffold`
  - `AccessibleTopBar`
  - `PrimaryActionButton`
  - `SecondaryActionButton`
  - `AppBottomNavigation`
  - `BrandIconBadge`
  - `StatusPill`
  - `StatusSummaryCard`
  - `FeatureNoteCard`
  - `SafetyNotice`
  - `ErrorNotice`
  - `SelectableInfoCard`
  - `SettingChoiceCard`
- Added routes and screens for Stitch references that were missing from the Module 2 shell:
  - `/permissions/camera`
  - `/help`
  - `/raspberry-pi/error`
- Added `mobile_app/test/app/module4_ui_migration_test.dart` with seven Module 4 widget tests.

### Changed

- Migrated Startup, Home, Mode Selection, Mobile Assistance, Raspberry Pi, Settings, and About/Safety from placeholders to native Flutter screens inspired by the Stitch references.
- Replaced conflicting Stitch copy with finalized scope-safe text for offline operation, generic object detection, estimated risk, local-only privacy, and assistive-aid limitations.
- Updated route enum/path/router coverage for all ten mapped Stitch screens.
- Extended `AppSettingsController` with in-memory feedback-mode and detection-sensitivity selection.
- Updated accessibility/router tests to use scroll-aware interactions and migrated UI keys.
- Added semantic containers for selectable cards and setting choices.

### Preserved

- All source files under `stitch/` were deliberately left unchanged.
- `mobile_app/pubspec.yaml` was left unchanged; no camera, AI, TTS, vibration, storage, WebView, Firebase, analytics, authentication, cloud, or Raspberry Pi networking dependency was added.

### Tests Executed

- `flutter --version`: hung for more than 60 seconds and was interrupted.
- `flutter --no-version-check --version`: passed; Flutter 3.44.5, Dart 3.12.2.
- `dart --version`: passed; Dart 3.12.2.
- `flutter doctor -v`: timed out under a 90-second guard.
- `flutter --no-version-check doctor -v`: completed with Android SDK missing, Xcode incomplete, CocoaPods missing, and XAMPP permission-scan warnings.
- `flutter pub get`: timed out under a 90-second guard.
- `flutter --no-version-check pub get`: passed.
- `dart format .`: passed during implementation.
- `dart format --output=none --set-exit-if-changed .`: passed; 0 changed files.
- `flutter analyze`: timed out under a 90-second guard.
- `flutter --no-version-check analyze`: passed; no issues found.
- `flutter test`: passed 35 tests after a non-blocking Flutter git fetch/version-check DNS message.
- `flutter --no-version-check test`: passed cleanly; 35 tests.
- `flutter build apk --debug`: failed with `[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.`
- `flutter --no-version-check build apk --debug`: failed with the same missing Android SDK message.
- `git status --short`: failed; workspace is not a Git repository.
- `git diff --stat`: failed; workspace is not a Git repository.

### Known Limitations

- Android debug build remains blocked because the Android SDK is missing.
- Manual TalkBack validation is blocked until an Android SDK and Android device/emulator are available.
- UI screens are native Flutter shells only; camera permission runtime, camera streaming, AI inference, TTS, vibration, local persistence, and Raspberry Pi communication remain deferred.
- Some plain Flutter commands remain unreliable unless `--no-version-check` is used.

## 2026-07-19 - Module 3: Stitch UI Analysis, Design-Token Extraction, Asset Audit, and Flutter Migration Blueprint

### Added

- Added Stitch source audit, design-system catalog, component inventory, interaction specification, responsive-layout specification, UI accessibility plan, screen-state matrix, and asset inventory.
- Added 393 x 852 rendered Stitch reference screenshots under `docs/rendered-stitch/`.
- Added Flutter design-token files for radii, shadows, icons, and motion.
- Added five theme-token tests in `mobile_app/test/app/theme_tokens_test.dart`.

### Changed

- Updated Flutter theme colors, typography, spacing, dimensions, button styles, card styles, switch/radio themes, and Material icon aliases based on Stitch token extraction.
- Replaced the UI migration map with stable `SCR-001` through `SCR-010` screen IDs and richer route/state/accessibility mapping.
- Updated requirements traceability with design-token, offline-asset, responsive-layout, and accessibility-planning requirements.
- Updated architecture, decision log, implementation plan, roadmap, testing notes, build/run notes, known issues, status, index, current module, and handoff docs.

### Fixed

- Replaced temporary Module 2 primary/background theme values with extracted Stitch colors.
- Added an accessible dark foreground token for text on the cyan primary color.

### Documentation Updated

- `docs/stitch-source-audit.md`
- `docs/design-system.md`
- `docs/component-inventory.md`
- `docs/interaction-spec.md`
- `docs/responsive-layout-spec.md`
- `docs/ui-accessibility-plan.md`
- `docs/screen-state-matrix.md`
- `docs/asset-inventory.md`
- `docs/ui-migration-map.md`
- `docs/requirements-traceability.md`
- `docs/architecture.md`
- `docs/decision-log.md`
- `docs/implementation-plan.md`
- `docs/ROADMAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/BUILD_AND_RUN.md`
- `docs/TESTING.md`
- `docs/INDEX.md`
- `docs/PROJECT_STATUS.md`
- `docs/CURRENT_MODULE.md`
- `docs/AGENT_HANDOFF.md`

### Tests Executed

- `flutter --no-version-check pub get`
- `dart format .`
- `dart format --output=none --set-exit-if-changed .`
- `flutter --no-version-check analyze`
- `flutter --no-version-check test`
- `flutter --no-version-check build apk --debug`

### Known Limitations

- Android debug build remains blocked because the Android SDK is missing.
- Chrome headless rendered reference screenshots but did not exit cleanly after capture.
- Original Stitch references still contain remote CDN/font/image URLs and conflicting copy; these must be corrected during native Flutter migration.
- No final screen migration, camera, AI inference, TTS, vibration, storage persistence, or Raspberry Pi networking was implemented.

## 2026-07-19 - Module 2: Flutter Engineering Foundation and Project Tracking System

### Added

- Added root agent guide and Markdown tracking system.
- Added feature-first Flutter source structure under `mobile_app/lib/`.
- Added app bootstrap with Flutter error-handler initialization and Riverpod `ProviderScope`.
- Added centralized route paths, route enum, route generator, and unknown-route screen.
- Added temporary centralized theme primitives.
- Added safe debug logger, app failure types, and `Result<T>`.
- Added foundational domain enums and entities for settings, feedback, detection settings, assistance session, and Raspberry Pi connection state.
- Added accessible placeholder screens for Startup, Home, Mode Selection, Mobile Assistance, Raspberry Pi, Settings, and About/Safety.
- Added organized tests under `test/app`, `test/core`, `test/domain`, and `test/accessibility`.
- Added `integration_test/app_startup_test.dart`.

### Changed

- Replaced the Module 1 single-file app shell with app/bootstrap/router/theme/features structure.
- Replaced the old widget smoke test with Module 2 route, accessibility, domain, and core tests.
- Updated implementation plan to align Module 2 with engineering foundation rather than final UI migration.
- Updated requirements traceability with implementation files, test IDs, and verification evidence.
- Expanded architecture and decision log with Module 2 implementation decisions.

### Fixed

- Fixed the documentation conflict where the old implementation plan described Module 2 as UI migration.

### Removed

- Removed the old single-screen `BaselineHomeScreen` implementation.

### Documentation Updated

- `AGENTS.md`
- `docs/INDEX.md`
- `docs/PROJECT_STATUS.md`
- `docs/CURRENT_MODULE.md`
- `docs/ROADMAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/AGENT_HANDOFF.md`
- `docs/BUILD_AND_RUN.md`
- `docs/TESTING.md`
- `docs/architecture.md`
- `docs/requirements-traceability.md`
- `docs/decision-log.md`
- `docs/implementation-plan.md`
- `docs/ui-migration-map.md`

### Tests Executed

- `dart --version`
- `flutter --no-version-check --version`
- `flutter --no-version-check doctor -v`
- `flutter --no-version-check pub get`
- `dart format .`
- `dart format --output=none --set-exit-if-changed .`
- `flutter --no-version-check analyze`
- `flutter --no-version-check test`
- `flutter --no-version-check build apk --debug`
- `flutter --no-version-check test integration_test` attempted but interrupted without a test result summary.

### Known Limitations

- Android debug build remains blocked because the Android SDK is missing.
- Plain Flutter commands time out in this environment unless `--no-version-check` is used.
- Integration test file exists but execution is not verified.
- Placeholder screens are not final Stitch UI conversions and do not implement camera, AI, TTS, vibration, storage persistence, or Raspberry Pi networking.

## 2026-07-19 - Module 1: Specification Freeze, Workspace Audit, and Engineering Baseline

### Added

- Created Android-only Flutter project at `mobile_app/`.
- Added Module 1 baseline documentation under `docs/`.
- Added minimal native Flutter baseline shell.
- Added baseline widget smoke tests.

### Changed

- Replaced generated Flutter counter demo with project-specific baseline screen.
- Updated Android launcher label to `AI Blind Assistant`.

### Fixed

- Removed generated placeholder comments from Android Gradle config.

### Removed

- Removed generated counter app behavior.

### Documentation Updated

- `docs/specification-baseline.md`
- `docs/requirements-traceability.md`
- `docs/architecture.md`
- `docs/ui-migration-map.md`
- `docs/implementation-plan.md`
- `docs/decision-log.md`
- `docs/workspace-audit.md`

### Tests Executed

- `dart format --output=none --set-exit-if-changed .`
- `flutter --no-version-check analyze`
- `flutter --no-version-check test`
- `flutter --no-version-check build apk --debug`

### Known Limitations

- Android debug build failed because the Android SDK was missing.
