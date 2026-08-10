# Changelog

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
