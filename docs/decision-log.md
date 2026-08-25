# Decision Log

## ADR-001: Native Flutter UI Instead of WebView

- Status: Accepted
- Context: Stitch HTML and CSS exist as design references, but the final app must be accessible, maintainable, and integrated with TalkBack.
- Decision: Recreate Stitch screens using native Flutter widgets. Do not embed HTML in a WebView for production UI.
- Consequences: UI migration takes longer, but accessibility, routing, state, testing, and platform integration remain under Flutter control.
- Verification: No WebView dependency or embedded production HTML route is allowed.

## ADR-002: Generic Person Detection Instead of Familiar-Person Recognition

- Status: Accepted
- Context: The project mentions person recognition, but familiar-face identification would add biometric data, identity storage, consent, privacy, and model complexity.
- Decision: The first production-quality version detects the generic model class `person` only.
- Consequences: The system may say that a person is detected, but must not identify who the person is.
- Verification: Requirements and UI copy use "person detected" or equivalent generic wording.

## ADR-003: Estimated Risk Instead of Exact Distance

- Status: Accepted
- Context: A monocular phone camera and lightweight detector cannot reliably produce exact physical distance without calibration or depth hardware.
- Decision: The system will estimate obstacle risk and proximity categories rather than claim exact meters.
- Consequences: Existing Stitch copy that says "3 meters ahead" must be changed before production use.
- Verification: Alert UI and speech use risk/proximity wording; risk estimator unit tests do not expose exact distance claims.

## ADR-004: Mobile Mode Before Raspberry Pi Mode

- Status: Accepted
- Context: Mobile Mode is the core Android app workflow and has fewer hardware dependencies.
- Decision: Implement and stabilize Mobile Mode first. Raspberry Pi Mode starts only after Mobile Mode meets its acceptance criteria.
- Consequences: Pi screens may exist as native UI earlier, but connection behavior remains deferred or clearly marked unavailable.
- Verification: Implementation plan gates Pi work behind Mobile Mode modules.

## ADR-005: Offline-Only Processing

- Status: Accepted
- Context: Privacy, latency, reliability, and FYP scope require local operation.
- Decision: Camera frames, detection, speech, haptics, and settings remain local. No cloud inference is allowed.
- Consequences: Model and assets must be packaged locally; CDN fonts/images from Stitch cannot be production dependencies.
- Verification: Airplane-mode tests and dependency/code review.

## ADR-006: Structured Vibration Patterns

- Status: Accepted
- Context: Continuous or uncontrolled vibration can be distracting, unsafe, and battery intensive.
- Decision: Use finite vibration patterns selected by alert severity, governed by cooldowns.
- Consequences: Haptics must be centralized in an alert orchestrator, not triggered directly from detection loops or widgets.
- Verification: Unit tests prove cooldown behavior and maximum pattern duration.

## ADR-007: Local-Only Settings

- Status: Accepted
- Context: The app has no accounts, cloud processing, or multi-user scope.
- Decision: Store preferences only on the device.
- Consequences: No sync or server migration is needed. Settings can be implemented behind a local `SettingsStore`.
- Verification: No settings network calls or user account dependencies.

## ADR-008: No Video Recording

- Status: Accepted
- Context: The app needs camera frames for immediate local inference, not media capture.
- Decision: Do not record or save video as part of the core app.
- Consequences: Storage, permissions, privacy policy, and UI copy are simpler.
- Verification: No video recorder dependency or save/upload workflow is added.

## ADR-009: No Cloud Analytics

- Status: Accepted
- Context: Analytics would conflict with the no-cloud, no-tracking project boundary.
- Decision: Do not add Firebase Analytics, crash analytics, telemetry, or remote logging.
- Consequences: FYP evaluation should use manual tests, local logs that avoid sensitive data, and documented observations.
- Verification: Dependency scan and code review.

## ADR-010: Accessible-by-Default UI

- Status: Accepted
- Context: The primary users may rely on TalkBack and non-visual feedback.
- Decision: Accessibility is a baseline requirement for every screen, not a final polish task.
- Consequences: Every feature module must include semantics, focus order, large text behavior, and accessible error states.
- Verification: Widget tests where possible and manual TalkBack walkthrough before demo.

## ADR-011: Selected Flutter Project

- Date: 2026-07-19
- Status: Accepted
- Context: Module 1 found no pre-existing Flutter project and created `mobile_app/`.
- Options considered: Continue with `mobile_app/`; create another Flutter project; use Stitch HTML directly.
- Decision: Keep `mobile_app/` as the selected main Flutter project.
- Rationale: It is the only valid Flutter project in the workspace and already preserves Stitch sources separately.
- Consequences: All Flutter code, dependencies, tests, and Android config are under `mobile_app/`.
- Related files: `mobile_app/`, `docs/workspace-audit.md`
- Related requirements: FR-001, CON-007

## ADR-012: Feature-First Architecture

- Date: 2026-07-19
- Status: Accepted
- Context: Module 2 needs a maintainable foundation before camera, inference, feedback, or Pi work starts.
- Options considered: Single flat `lib/`; strict layer-only folders; feature-first layered folders.
- Decision: Use feature-first layered architecture with shared app, core, domain, infrastructure, and feature folders.
- Rationale: Feature-first structure makes future modules easier to isolate while preserving domain/infrastructure boundaries.
- Consequences: Placeholder screens live under `features/*/presentation`; shared contracts live under `domain/` and `core/`.
- Related files: `mobile_app/lib/`
- Related requirements: NFR-MAINT-001, NFR-MAINT-002

## ADR-013: Riverpod State Management

- Date: 2026-07-19
- Status: Accepted
- Context: Module 1 did not approve an existing state-management approach, and Module 2 requires one consistent approach.
- Options considered: Riverpod; Flutter `InheritedWidget` only; adding multiple state libraries.
- Decision: Use `flutter_riverpod` as the single state-management approach.
- Rationale: Riverpod supports immutable state, focused providers, test replacement, and dependency injection without platform services.
- Consequences: `ProviderScope` wraps the app and providers live in `mobile_app/lib/app/providers.dart`.
- Related files: `mobile_app/pubspec.yaml`, `mobile_app/lib/app/bootstrap.dart`, `mobile_app/lib/app/providers.dart`
- Related requirements: FR-004, NFR-MAINT-001

## ADR-014: Dependency Injection Through Providers

- Date: 2026-07-19
- Status: Accepted
- Context: Future services need replaceable boundaries without global mutable singletons.
- Options considered: Manual constructor injection only; service locator; Riverpod providers.
- Decision: Use Riverpod providers as the dependency-injection mechanism.
- Rationale: This keeps services testable and avoids adding another DI package.
- Consequences: Future camera, inference, settings, feedback, and Pi services should be exposed through abstractions and providers.
- Related files: `mobile_app/lib/app/providers.dart`
- Related requirements: NFR-MAINT-001, NFR-REL-001

## ADR-015: Centralized Flutter Routing

- Date: 2026-07-19
- Status: Accepted
- Context: Module 2 requires central routes, unknown-route handling, and navigation tests without adding unnecessary packages.
- Options considered: Flutter `onGenerateRoute`; `go_router`; hardcoded `Navigator` strings.
- Decision: Use Flutter `MaterialApp.onGenerateRoute` with central `AppRoute` and `RoutePaths`.
- Rationale: The initial route set is small, and core Flutter routing avoids an extra dependency.
- Consequences: Widgets must navigate through `AppRoute.*.path`, and unknown routes render `UnknownRouteScreen`.
- Related files: `mobile_app/lib/app/router/`
- Related requirements: FR-023, NFR-MAINT-001

## ADR-016: Route Naming

- Date: 2026-07-19
- Status: Accepted
- Context: Routes need stable names for tests and future modules.
- Options considered: Stitch route names; feature-oriented route names; generated route names.
- Decision: Use feature-oriented stable paths: `/startup`, `/home`, `/modes`, `/mobile-assistance`, `/raspberry-pi`, `/settings`, and `/about-safety`.
- Rationale: These names match Module 2 placeholders and avoid implying final Stitch screen conversion.
- Consequences: Module 4 may add or adapt routes for final Stitch screens while preserving these foundation routes where useful.
- Related files: `mobile_app/lib/app/router/route_paths.dart`
- Related requirements: FR-023

## ADR-017: Error-Handling Strategy

- Date: 2026-07-19
- Status: Accepted
- Context: Later platform features need recoverable, user-safe failures.
- Options considered: Throw raw exceptions to UI; broad exception strings; foundational failure/result types.
- Decision: Add `AppFailure` categories and `Result<T>` foundation.
- Rationale: This creates a testable boundary without implementing later runtime recovery flows.
- Consequences: Future services should return or map failures to safe user messages and keep stack traces out of UI.
- Related files: `mobile_app/lib/core/errors/app_failure.dart`, `mobile_app/lib/core/result/result.dart`
- Related requirements: FR-020, NFR-REL-001

## ADR-018: Logging Restrictions

- Date: 2026-07-19
- Status: Accepted
- Context: Assistive camera workflows can involve sensitive visual data in later modules.
- Options considered: No logging foundation; debug-only safe logger; remote logging.
- Decision: Add a debug-only safe logger and prohibit sensitive data in logs.
- Rationale: Developers need basic diagnostics, but privacy boundaries must be explicit before camera work starts.
- Consequences: No camera frames, image bytes, face data, audio recordings, personal identifiers, or secrets may be logged.
- Related files: `mobile_app/lib/core/logging/`, `AGENTS.md`, `docs/architecture.md`
- Related requirements: NFR-SEC-001, NFR-SEC-002

## ADR-019: Documentation Governance

- Date: 2026-07-19
- Status: Accepted
- Context: Future agents need to continue without relying on chat history.
- Options considered: Keep only Module 1 docs; add living tracking docs; rely on comments.
- Decision: Add `AGENTS.md` and living docs for index, status, current module, roadmap, changelog, known issues, handoff, build/run, and testing.
- Rationale: The project is multi-module and academic, so traceability and exact handoff matter.
- Consequences: Future modules must update status, traceability, decisions, known issues, and handoff before completion.
- Related files: `AGENTS.md`, `docs/INDEX.md`, `docs/PROJECT_STATUS.md`, `docs/CURRENT_MODULE.md`, `docs/AGENT_HANDOFF.md`
- Related requirements: BR-002, NFR-MAINT-002

## ADR-020: Semantic Flutter Tokens From Stitch

- Date: 2026-07-19
- Status: Accepted
- Context: Stitch provides Tailwind class names and inline configuration, while Flutter needs maintainable theme primitives.
- Options considered: Copy Tailwind class names into widgets; define semantic Flutter tokens; defer tokens to Module 4.
- Decision: Extract Stitch values into semantic Flutter token files under `mobile_app/lib/app/theme/`.
- Rationale: Semantic tokens keep widgets readable and allow accessibility corrections without hardcoding Tailwind implementation details.
- Consequences: Module 4 screens must consume `AppColors`, `AppSpacing`, `AppDimensions`, `AppRadii`, `AppShadows`, `AppIcons`, `AppMotion`, and `AppTypography`.
- Related files: `docs/design-system.md`, `mobile_app/lib/app/theme/`
- Related requirements: NFR-MAINT-001, NFR-MAINT-003, CON-001

## ADR-021: Accessible Primary Foreground Color

- Date: 2026-07-19
- Status: Accepted
- Context: Stitch uses cyan primary `#25c0f4` with dark foreground text through `text-background-dark`.
- Options considered: Use white text on primary; use dark text on primary; change primary color.
- Decision: Keep Stitch primary `#25c0f4` and use dark `AppColors.onPrimary` for primary-button text.
- Rationale: Dark text preserves the Stitch visual intent and provides accessible contrast.
- Consequences: Module 4 must avoid white text over `AppColors.primary` for body/button copy unless contrast is rechecked.
- Related files: `mobile_app/lib/app/theme/app_colors.dart`, `mobile_app/test/app/theme_tokens_test.dart`
- Related requirements: NFR-ACC-002

## ADR-022: Remote Stitch Assets Are References Only

- Date: 2026-07-19
- Status: Accepted
- Context: Stitch loads Tailwind, Google Fonts, Material Symbols, and several images from remote URLs.
- Options considered: Keep remote URLs in Flutter; download/use them without review; replace them with local approved assets or native icon compositions.
- Decision: Treat all remote Stitch assets as references only. Production Flutter must use local approved assets or native Flutter icons/shapes.
- Rationale: The app must work offline and avoid unreviewed runtime network dependencies.
- Consequences: Module 4 must not add network image/font loading for UI assets.
- Related files: `docs/asset-inventory.md`, `docs/stitch-source-audit.md`
- Related requirements: NFR-OFFLINE-001, NFR-OFFLINE-002, NFR-SEC-001

## ADR-023: Flutter Material Icons Over Remote Material Symbols

- Date: 2026-07-19
- Status: Accepted
- Context: Stitch uses Google Material Symbols through a remote font.
- Options considered: Use remote Material Symbols; bundle a Material Symbols font; map to Flutter Material icons.
- Decision: Use Flutter Material icon aliases through `AppIcons` for the first native UI migration.
- Rationale: Flutter Material icons are available offline, require no font licensing step in this module, and integrate with native semantics.
- Consequences: Some glyphs may differ slightly from Stitch, but semantic meaning and offline reliability take priority.
- Related files: `mobile_app/lib/app/theme/app_icons.dart`, `docs/asset-inventory.md`
- Related requirements: NFR-OFFLINE-002, CON-001

## ADR-024: Responsive Flutter Layouts Instead Of Fixed Stitch Canvas

- Date: 2026-07-19
- Status: Accepted
- Context: Stitch pages use `min-height: max(884px, 100dvh)` and many `overflow-hidden` layouts.
- Options considered: Recreate fixed 884 px layouts; use responsive native layouts with scroll/safe areas; defer responsiveness.
- Decision: Module 4 must preserve visual intent while using safe-area-aware, scrollable, text-scale-safe Flutter layouts.
- Rationale: Blind and low-vision Android users may use large fonts and different device sizes.
- Consequences: Pixel-perfect fixed-height reproduction is not the acceptance criterion; accessible responsive equivalence is.
- Related files: `docs/responsive-layout-spec.md`
- Related requirements: NFR-RESP-001, NFR-RESP-002, NFR-ACC-002

## ADR-025: Rendered Stitch Screenshots Are Documentation Artifacts

- Date: 2026-07-19
- Status: Accepted
- Context: Module 3 generated 393 x 852 screenshots from Stitch HTML for migration reference.
- Options considered: Register rendered screenshots in Flutter assets; store them as docs-only artifacts; discard them after audit.
- Decision: Keep rendered screenshots under `docs/rendered-stitch/` as reference artifacts only.
- Rationale: They help future migration and review without becoming production UI.
- Consequences: `pubspec.yaml` must not register these screenshots as app UI assets.
- Related files: `docs/rendered-stitch/`, `docs/stitch-source-audit.md`
- Related requirements: CON-001, CON-007

## ADR-026: Module 4 Starts With Startup Screen

- Date: 2026-07-19
- Status: Accepted
- Context: Module 4 needs a low-risk first screen to validate native tokens and accessibility patterns.
- Options considered: Start with assistance-running UI; start with settings; start with startup/splash.
- Decision: Start Module 4 with SCR-001 Startup/Welcome screen.
- Rationale: It exercises brand colors, typography, icon badge, primary button, and route semantics without depending on camera, settings persistence, or AI state.
- Consequences: Module 4 should migrate `StartupScreen` first, then reuse the pattern for the remaining screens.
- Related files: `docs/ui-migration-map.md`, `docs/implementation-plan.md`
- Related requirements: FR-001, NFR-MAINT-003

## ADR-027: Use LiteRT Artifact for AGP 9 Compatibility

- Date: 2026-07-26
- Status: Accepted
- Context: AGP 9 rejected legacy TensorFlow Lite/support artifacts. During the real-model pass, LiteRT 2.1.6 was also tested and rejected because its published `litert` and `litert-api` AARs declare the same Android namespace.
- Options considered: Keep LiteRT 1.0.1; use 2.1.6 and downgrade AGP; use the latest compatible monolithic artifact; add Play AI model delivery.
- Decision: Use `com.google.ai.edge.litert:litert:2.1.5` with `isTransitive = false`.
- Rationale: 2.1.5 is the latest verified artifact that preserves the `org.tensorflow.lite.Interpreter` API and passes the current AGP 9 build. The app needs only the bundled native interpreter, not Play AI delivery or lifecycle dependencies.
- Consequences: Android inference is fully local, the production manifest avoids model-delivery/network permissions, and 2.1.6 remains blocked until its namespace packaging is compatible.
- Related files: `mobile_app/android/app/build.gradle.kts`, `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/InferenceHandler.kt`
- Related requirements: FR-009, NFR-OFFLINE-001, NFR-MAINT-001

## ADR-028: Pin Official YOLOv8n and Package a Verified FP32 LiteRT Model

- Date: 2026-08-06
- Status: Accepted
- Context: Mobile Mode had an export script and labels but no model asset. The first reliable integration needs official provenance, a fixed mobile input, and a tensor contract verified from the exported file.
- Options considered: Download a third-party TFLite file; export official YOLOv8n as FP16; export calibrated INT8; export official YOLOv8n through the current LiteRT exporter as FP32.
- Decision: Pin official Ultralytics assets release `v8.4.0` weights by SHA-256, export at 320 x 320 without embedded NMS, and bundle the verified FP32 LiteRT asset, COCO labels, and generated metadata.
- Rationale: The current exporter does not emit a distinct FP16 model, while the verified FP32 model works through the CPU/XNNPACK fallback. INT8 would require a real representative calibration dataset and accuracy evaluation.
- Consequences: The APK is larger than an INT8 build but has an honest, working tensor contract. Future model replacement must update provenance, labels, metadata, parser/risk mappings, tests, and physical evaluation together.
- Related files: `scripts/export_yolov8n.py`, `scripts/model_export_requirements.txt`, `mobile_app/assets/models/`, `docs/model-integration.md`
- Related requirements: FR-009, FR-010, NFR-OFFLINE-001, NFR-PERF-001, BR-003

## ADR-029: Perform Stride-aware Preprocessing and LiteRT Inference on a Native Background Executor

- Date: 2026-08-06
- Status: Accepted
- Context: Concatenating YUV planes as NV21, stretching frames to a square, hard-coding tensors, and running inference on the main thread produced incorrect color/geometry and unsafe latency.
- Options considered: Convert frames to JPEG in Dart; use a new Flutter inference package and parallel architecture; keep the existing MethodChannel and harden the native bridge.
- Decision: Preserve the existing MethodChannel, pass three YUV planes and their strides, perform direct RGB conversion, rotation/mirror correction and RGB-114 letterboxing natively, inspect actual tensors, warm up, reuse direct buffers, and run one inference at a time on a background executor.
- Rationale: This fixes the real Android camera contract, keeps heavy work off both Flutter and Android UI threads, prevents inference queues, and preserves the selected architecture.
- Consequences: Native and Dart metadata are cross-checked; boxes are unletterboxed into preview coordinates; CPU/XNNPACK remains the safe default. Hardware delegates require a later device-specific decision.
- Related files: `mobile_app/lib/domain/services/camera_service.dart`, `mobile_app/lib/infrastructure/camera/mobile_camera_service.dart`, `mobile_app/lib/infrastructure/inference/tflite_inference_service.dart`, `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/InferenceHandler.kt`
- Related requirements: FR-008, FR-009, NFR-PERF-001, NFR-PERF-002, NFR-MAINT-001

## ADR-030: Require Stable Priority Alerts and Explicit Resume

- Date: 2026-08-06
- Status: Accepted
- Context: Announcing every frame would overwhelm a blind user, while automatic assistance restart after backgrounding could activate the camera unexpectedly.
- Options considered: Announce every detection; use cooldown only; add spatial stability, priority/rate controls, and explicit resume.
- Decision: Require two consecutive spatial matches, suppress low risk, rank by size/centrality/safety class, select one alert, use per-class cooldown plus duplicate/global rate controls, allow critical upgrades, bound every haptic pattern, and require explicit user resume after lifecycle pause.
- Rationale: Stable, concise, user-controlled feedback is safer and more accessible than high-frequency narration or silent automatic camera restart.
- Consequences: Very short-lived detections may be omitted. Resume shows Paused rather than automatically starting. Physical usability and TalkBack/TTS cadence still require user testing.
- Related files: `mobile_app/lib/infrastructure/detection/detection_stabilizer.dart`, `mobile_app/lib/infrastructure/detection/obstacle_risk_assessor.dart`, `mobile_app/lib/infrastructure/feedback/feedback_alert_orchestrator.dart`, `mobile_app/lib/app/assistance_controller.dart`
- Related requirements: FR-011, FR-012, FR-013, FR-014, FR-020, NFR-ACC-001, CON-005, BR-004

## ADR-031: Begin Wearable Mode by Explicit Owner Authorization

- Date: 2026-08-07
- Status: Accepted
- Context: The baseline sequenced Raspberry Pi work after physical Mobile Mode acceptance, which remains incomplete. The owner explicitly requested complete wearable integration now while requiring Mobile Mode independence.
- Options considered: Refuse all Pi work until phone acceptance; replace Mobile Mode; implement the isolated wearable module while retaining the open Mobile acceptance gate.
- Decision: Implement Module 15 through separate domain/infrastructure/controller seams without modifying the working Mobile pipeline, and keep every unperformed physical Mobile check open.
- Rationale: The latest explicit task authorizes the scope change, while architectural isolation prevents it from turning an unavailable Pi into a Mobile Mode regression.
- Consequences: `CON-004` is interpreted as sequencing guidance superseded for this owner-authorized pass, not evidence that Mobile Mode passed physical acceptance. Both phone and Pi hardware checks remain truthful blockers.
- Related files: `mobile_app/lib/app/wearable_controller.dart`, `raspberry_pi/`, `docs/wearable-mode.md`
- Related requirements: CON-004, NFR-MAINT-001, NFR-REL-001

## ADR-032: Authenticated Local WebSocket with Native NSD and Secure Storage

- Date: 2026-08-07
- Status: Accepted
- Context: Wearable Mode needs offline bidirectional control, discovery, revocable pairing, reconnects, and compact telemetry without a cloud dependency. Full device-certificate TLS bootstrap cannot be made trustworthy by accepting arbitrary self-signed certificates.
- Options considered: Bluetooth transport; unauthenticated TCP; cloud relay; globally bypass TLS validation; authenticated local WebSocket with an explicit private-LAN boundary.
- Decision: Use protocol-v1 WebSocket, Android NSD/mDNS plus saved/manual fallback, short-lived local codes, Keystore AES-GCM credential storage, protected Pi verifiers, HMAC challenge authentication and per-message integrity, replay controls, heartbeats, acknowledgements, and bounded retry. Do not bypass certificate validation.
- Rationale: This is small enough for the Pi 3B, testable without hardware, survives address changes, and provides device authentication/integrity while preserving offline operation.
- Consequences: Protocol v1 does not provide confidentiality and first pairing must occur on a trusted private LAN. The service must bind to its intended private interface and never be exposed to the public internet. A future pinned/managed TLS layer can retain the typed messages.
- Related files: `docs/wearable-protocol.md`, `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/WearablePlatformHandler.kt`, `raspberry_pi/`
- Related requirements: NFR-OFFLINE-001, NFR-SEC-001, NFR-SEC-002, NFR-REL-001

## ADR-033: Pi Owns Essential Wearable Feedback and NCNN Runtime

- Date: 2026-08-07
- Status: Accepted
- Context: Wearable assistance must continue after phone disconnection and must not double-speak. The finalized detector is a 320 x 320 YOLOv8n Open Images V7 NCNN export with 601 labels.
- Options considered: Run inference on phone from streamed frames; install Ultralytics/PyTorch on Pi; make phone the only feedback owner; keep inference and essential feedback local to Pi.
- Decision: Load the NCNN model once on the Pi, use Picamera2 with latest-frame dropping, parse labels from export metadata, apply confidence/NMS/relative visual priority, and make Pi local speech the default feedback owner. Send compact detections/status/health to Flutter; never send continuous raw frames.
- Rationale: This preserves privacy, offline independence, bounded memory/latency, and feedback continuity on a 1 GB Pi.
- Consequences: Phone speech is suppressed unless a future explicit feedback-ownership setting requests it. OIV7 class IDs must never be replaced by COCO mappings. OV5647 CSI stability remains a physical hardware check.
- Related files: `raspberry_pi/`, `docs/wearable-mode.md`
- Related requirements: NFR-OFFLINE-001, NFR-PERF-001, NFR-SEC-001, BR-004

## ADR-034: One Strict Cross-Language Wearable Protocol Contract

- Date: 2026-08-09
- Status: Accepted
- Context: The pre-existing Flutter and Python implementations used different WebSocket paths, mDNS names, timestamps, authentication names/canonicalization, settings payloads, acknowledgement shapes, direction values, and health/detection schemas. Each side compiled independently but could not interoperate.
- Options considered: Add translation shims; keep two loosely documented schemas; make the existing Flutter protocol-v1 codec the strict cross-language contract and test fixed HMAC vectors plus a real cross-stack simulator.
- Decision: Standardize both runtimes on `_aiba-wearable._tcp`, `/wearable/v1`, ISO-UTC strict envelopes, signed `authentication`, length-prefixed nonce-bound HMAC hex, direct versioned settings snapshots, left/center/right OIV7 detections, and correlated `requestMessageId` acknowledgement/error fields. Reject unknown protocol-v1 fields and test the Flutter client against the actual Python service process.
- Rationale: One strict contract eliminates silent schema drift, enables deterministic validation and replay protection, and turns the simulator into meaningful integration evidence rather than two unrelated unit-test suites.
- Consequences: Protocol changes require synchronized codec/model updates and cross-stack tests. Protocol v1 remains application-authenticated plain WebSocket without confidentiality, as recorded in ADR-032.
- Related files: `docs/wearable-protocol.md`, `mobile_app/lib/infrastructure/networking/`, `raspberry_pi/src/ai_blind_pi/`, `mobile_app/test/features/wearable/`, `raspberry_pi/tests/`
- Related requirements: NFR-REL-001, NFR-SEC-001, NFR-SEC-002, NFR-MAINT-001

## ADR-035: Dynamically Select One Private Pi Interface

- Date: 2026-08-09
- Status: Accepted
- Context: Persisting a DHCP address in the service environment breaks after a Pi address change, while wildcard binding would expose the port on every current and future interface.
- Options considered: hardcode the current address; bind `0.0.0.0`; require manual redeployment after DHCP changes; select one concrete private interface at startup and restart boundedly when it changes.
- Decision: Install `AIBA_BIND_HOST=auto`, prefer the Pi wireless then Ethernet private IPv4 interface, never bind a wildcard, monitor that selection, and request a clean systemd `on-failure` restart when the selected address changes. Allow an explicit validated private address as an owner override.
- Rationale: This supports DHCP changes and fresh mDNS advertisement while retaining a narrower network exposure than wildcard listening.
- Consequences: A real interface change briefly restarts the service and active assistance; systemd start limits prevent a flapping network from causing an infinite restart loop. Multi-interface deployments may explicitly select the intended private address.
- Related files: `raspberry_pi/src/ai_blind_pi/config.py`, `raspberry_pi/src/ai_blind_pi/cli.py`, `raspberry_pi/config/wearable.env.example`, `raspberry_pi/scripts/install.sh`
- Related requirements: FR-019, NFR-REL-001, NFR-SEC-001

## ADR-036: Use an Ignored Local Signing Identity and Deliver an ARM64 Release

- Date: 2026-08-09
- Status: Accepted
- Context: The project needs a shareable release APK, had no legitimate release-signing configuration, targets a modern physical Android phone, and the host initially contained only a partial NDK installation.
- Options considered: ship a debug-signed APK; commit a keystore/password; block all release work; create a protected ignored project identity and build the target ARM64 ABI.
- Decision: Generate a local RSA-3072 signing identity and properties file with restrictive modes, ignore both, load them only in the Gradle release variant, and deliver a split ARM64-v8a APK. Preserve the existing application ID rather than silently creating a new installed product identity.
- Rationale: This produces an installable, updateable local release without exposing signing secrets or adding machine-specific paths. ARM64 matches the intended phone class and avoids claiming unverified multi-ABI support.
- Consequences: Both ignored signing files must be securely backed up for future updates. The final APK does not support legacy 32-bit-only devices. A public-store release should use an owner-controlled permanent package identity and managed signing process.
- Related files: `scripts/configure_release_signing.sh`, `mobile_app/android/app/build.gradle.kts`, `.gitignore`, `docs/RELEASE_CHECKLIST.md`
- Related requirements: FR-001, NFR-SEC-002, NFR-MAINT-002

## ADR-037: Preserve Platform Text Scaling and Explicit Heading Structure

- Date: 2026-08-14
- Status: Accepted
- Context: The saved large-text preference replaced Android's platform scaler with a new linear factor, which discarded nonlinear accessibility behavior. Boolean semantic headers also lacked document structure and are being superseded by explicit heading levels in Flutter.
- Options considered: Keep the fixed linear scaler and boolean headers; force one larger global font size; compose a bounded preference scaler with the platform curve and expose explicit levels.
- Decision: Preserve the ambient `TextScaler`, apply the preference as a 1.2 multiplier capped at 2.5, use heading level 1 for route titles and level 2 for sections, and enforce tap-target/label/contrast guidelines in widget tests.
- Rationale: Platform accessibility behavior remains authoritative while the saved preference still has a predictable effect; structured headings improve screen-reader navigation and the automated guidelines catch common regressions.
- Consequences: Physical TalkBack and Android font/display scaling still require real-device acceptance. Future Flutter upgrades must retain the composed nonlinear behavior and rerun the guideline suite.
- Related files: `mobile_app/lib/core/accessibility/preferred_text_scaler.dart`, `mobile_app/lib/app/app.dart`, `mobile_app/lib/core/widgets/app_screen_scaffold.dart`, `mobile_app/test/accessibility/`
- Related requirements: NFR-ACC-001, NFR-ACC-002, NFR-ACC-003, NFR-RESP-001

## ADR-038: Disable the Unapproved Personalized Assistant in Standard Builds

- Date: 2026-08-14
- Status: Accepted
- Context: Pre-existing uncommitted source introduced authentication, microphone recording, personal data and a laptop HTTP backend, conflicting with the approved scope. The feature was reachable but Android had no native audio channels, ordinary SharedPreferences held its bearer token, and enabling it would create false functionality and an unreviewed privacy boundary.
- Options considered: Ship it as-is; delete the user-owned work; silently add prohibited permissions/authentication; preserve it outside the production import graph.
- Decision: Preserve the experiment, remove all Home/router production imports, verify its identifying strings are absent from release AOT, remove microphone permission, and make absent native channels fail truthfully. Do not include it in approved release claims.
- Rationale: The standard release remains consistent with the governing specification without destroying user work or pretending that an incomplete security/audio stack is professional.
- Consequences: Direct experiment tests remain available, but the feature cannot be enabled for release without explicit scope approval, threat modeling, encrypted credential storage, transport security, native audio implementation, retention rules and physical accessibility validation.
- Related files: `mobile_app/lib/core/config/experimental_features.dart`, `mobile_app/lib/app/router/`, `mobile_app/lib/features/home/presentation/home_screen.dart`, `mobile_app/android/app/src/main/AndroidManifest.xml`, `laptop_backend/`
- Related requirements: CON-002, CON-006, NFR-SEC-002, NFR-MAINT-001

## ADR-039: Authorize a Bounded Hybrid In-App Voice Assistant

- Date: 2026-08-14
- Status: Accepted; supersedes ADR-038 for current releases
- Context: The owner explicitly requested in-app voice control, local Ollama,
  optional Gemini, automatic local fallback, Raspberry Pi commands, and phone
  deployment. The preserved experiment needed a complete security, privacy,
  accessibility, and execution boundary before it could be enabled.
- Options considered: keep the assistant disabled; use Gemini-only cloud
  reasoning; use Ollama-only local reasoning; implement Gemini-first reasoning
  with deterministic controls and automatic Ollama fallback.
- Decision: Enable typed and explicit push-to-talk interaction. Transcribe on
  the paired laptop with local Whisper. Route common commands deterministically;
  otherwise prefer Gemini only when an environment key exists and fall back to
  Ollama on every provider failure. Allow only schema-validated tools, require
  confirmation for sensitive actions, execute phone actions through existing
  controllers, and verify the resulting state. Store pair credentials through
  Android Keystore. Gemini receives text only with `store: false`; no camera
  frame or raw recording may be sent. Core assistance stays offline.
- Rationale: This meets the requested experience while keeping safety-critical
  control deterministic, bounded, reversible, and locally usable.
- Consequences: The assistant needs a paired laptop. Without a Gemini key it is
  entirely local. With a key, typed/transcribed content is disclosed to Google.
  Authenticated HTTP lacks confidentiality and is trusted-LAN-only pending TLS.
  Always-on listening, wake words, OS-wide control and unconfirmed sensitive
  actions remain out of scope. Physical voice/TalkBack/Gemini acceptance is
  mandatory before a final product claim.
- Related files: `docs/assistant.md`, `laptop_backend/`,
  `mobile_app/lib/features/assistant/`,
  `mobile_app/lib/app/assistant_session_controller.dart`
- Related requirements: FR-013 through FR-022, NFR-OFFLINE-002,
  NFR-SEC-002 through NFR-SEC-004, NFR-REL-001, CON-002

## ADR-040: Execute Basic Typed App Controls Entirely On-Device

- Date: 2026-08-14
- Status: Accepted; refines ADR-039
- Context: Basic commands such as changing sensitivity, starting Mobile Mode,
  or connecting a Raspberry Pi must remain available offline and must not fail
  merely because the optional conversational backend or AI provider is absent.
- Options considered: send every typed request to the laptop; use an LLM on the
  phone; duplicate a bounded deterministic command policy on the phone and
  laptop; claim voice independence without an on-device speech model.
- Decision: Parse allow-listed typed app commands in the Flutter domain layer
  before checking assistant credentials or network health. Execute them through
  the existing Riverpod controllers, retain confirmation for sensitive changes,
  and generate truthful result text on-device. Keep the equivalent deterministic
  matcher after local Whisper for spoken commands. Only unmatched conversational
  requests may use Gemini-first/Ollama-fallback reasoning.
- Rationale: Core controls remain predictable and usable with no internet,
  backend, or model while voice retains local transcription and the same bounded
  action semantics.
- Consequences: Typed controls are standalone on the phone. Spoken controls are
  internet-independent but still require the paired laptop for Whisper; a future
  verified on-device STT implementation would be required for laptop-free voice.
  The two deterministic phrase suites must remain synchronized by tests.
- Related files: `mobile_app/lib/domain/services/offline_app_command_parser.dart`,
  `mobile_app/lib/app/assistant_session_controller.dart`,
  `laptop_backend/src/ai_assistant/tools/local_commands.py`, `docs/assistant.md`
- Related requirements: FR-015, FR-016, FR-017, NFR-OFFLINE-002,
  NFR-REL-001, NFR-MAINT-001

## ADR-041: Require Dedicated On-Device Speech for App Controls

- Date: 2026-08-14
- Status: Accepted; refines ADR-039 and ADR-040
- Context: The owner requires voice control of app settings, Mobile Mode, and
  Raspberry Pi operations without internet or a laptop backend. The prior
  phone recorder plus laptop Whisper path did not satisfy that requirement.
- Options considered: keep laptop Whisper; use Android's ordinary
  `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE`; bundle a separate neural STT
  runtime/model; require Android 12+'s dedicated on-device recognizer and fail
  truthfully when the offline service/language is absent.
- Decision: Use `SpeechRecognizer.isOnDeviceRecognitionAvailable` and
  `createOnDeviceSpeechRecognizer` on API 31+. Never use the ordinary recognizer
  as an app-control fallback because Android documents it as potentially remote
  and documents the offline preference as implementation-dependent. Keep the
  transcript in memory, run the deterministic Flutter parser before any network
  check, retain confirmation for sensitive actions, and send only unmatched
  general-conversation text to an explicitly paired optional backend.
- Rationale: This makes the privacy and offline guarantee enforceable in code,
  removes the laptop from the app-control path, preserves bounded deterministic
  behavior, and avoids silently changing to cloud speech.
- Consequences: Offline voice needs Android 12+ and an installed on-device
  recognition service/language pack. Older or unsupported devices retain typed
  controls and receive truthful setup guidance. The optional Gemini/Ollama
  backend remains available for general conversation only. Physical voice,
  language-pack, microphone, and TalkBack acceptance remain mandatory.
- Related files:
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`,
  `mobile_app/lib/domain/services/on_device_speech_recognition_service.dart`,
  `mobile_app/lib/app/assistant_session_controller.dart`, `docs/assistant.md`
- Related requirements: FR-013 through FR-018, NFR-OFFLINE-002,
  NFR-SEC-003, NFR-REL-001, NFR-MAINT-001

## ADR-042: Bundle Foreground Hands-Free Speech and Wake Activation

- Date: 2026-08-14
- Status: Accepted; supersedes the no-wake portion of ADR-039 and the
  service-only dependency in ADR-041; decoder details refined by ADR-043
- Context: The target TECNO BG6 has no installed dedicated on-device speech
  service, and the owner requires a blind user to operate the already-open app
  by calling the assistant without touching the screen.
- Options considered: retain push-to-talk; depend on a vendor/Google speech
  service; add a background Android assistant service; bundle phone-local
  recognition and limit continuous listening to the foreground app.
- Decision: Package the official Vosk small English model and use it for the
  foreground “Hey Vision AI” wake and command listener. Restrict the idle
  decoder to a small brand-specific grammar with `[unk]`, then switch to the
  default full-vocabulary graph only for the bounded command/confirmation
  window. Suppress duplicate result/final callbacks. Keep manual
  voice as an alternative, preferring the dedicated Android recognizer and
  falling back to Vosk. Pause recognition during TTS and confirmations; accept
  confirmation/cancellation by voice; serialize background/resume operations;
  keep the screen awake while foregrounded; stop on background or lock. Never
  use Android's ordinary possibly remote recognizer.
- Rationale: The user gets a laptop-free, internet-free, service-independent
  control path while raw audio remains transient on the phone and the feature
  stays inside the explicitly opened app.
- Consequences: The ARM64 APK grows to about 97 MB, the bundled vocabulary is
  English, and continuous foreground recognition uses battery. This is not a
  system Siri replacement and cannot activate from another app or a locked
  screen. Real accent/noise, TalkBack, TTS/audio-focus, and battery/thermal
  acceptance remain required. Sensitive settings and connection changes still
  require spoken or accessible-button confirmation.
- Related files:
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`,
  `mobile_app/android/app/src/main/assets/model-en-us/`,
  `mobile_app/lib/app/assistant_session_controller.dart`, `docs/assistant.md`
- Related requirements: FR-013 through FR-015, NFR-OFFLINE-002,
  NFR-SEC-003, NFR-REL-001, BR-003

## ADR-043: Use Safe Two-Stage Vosk Decoding and Contextual Smart AI Speech

- Date: 2026-08-20
- Status: Accepted; refines ADR-042
- Context: The owner reported wrong transcripts, noise sensitivity, missing
  semantic command variants, Smart AI voice inconsistency, and unexpected app
  exits. Inspection found that any settled nonempty partial could previously
  activate hands-free mode and that profile changes replaced a private final
  Vosk recognizer through reflection while its audio thread could still decode.
- Options considered: send raw audio to laptop faster-whisper; add a large
  on-device Whisper runtime; use a proprietary system-assistant/wake SDK; keep
  Vosk but separate wake, app-command, scanner, and conversation graphs with a
  single serialized microphone owner.
- Decision: Keep raw audio on the phone and retain bundled Vosk for the visible
  foreground app. Idle decoding uses only complete branded wake phrases and
  acts on final results, never generic partial hypotheses. After acknowledgement,
  a constrained app/scanner grammar handles deterministic commands. Decoder
  changes call `SpeechService.cancel()` to interrupt and join the worker before
  resetting grammar and restarting the same service; the private recognizer is
  never reflected into or hot-swapped. Retain supported AEC/NS/AGC effects.
  `VisionVoiceKernelV3` serializes hands-free and push-to-talk microphone use.
  On the Smart AI route, use the same Vosk/AudioRecord path with the default
  conversation graph; local commands retain priority, only unmatched transcript
  text reaches the paired backend, and “bye”/“by” restores offline wake mode.
  Faster-whisper remains a retained laptop service and is not used by the
  current mobile voice path because that would require raw-audio transport or a
  separately validated on-device runtime.
- Rationale: This removes the two identified false-activation/native-race
  mechanisms while preserving offline app control, privacy, and the existing
  low-end Android deployment. It also gives Smart AI one consistent foreground
  capture lifecycle without treating an LLM as an app-control router.
- Consequences: This is not Siri/Google Assistant parity or a system-wide wake
  service. The bundled English model, grammar, device microphones, and vendor
  audio effects limit accuracy. Physical accent/noise, repeated profile-change,
  TalkBack, battery, thermal, and crash-log acceptance remain mandatory.
- Related files:
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`,
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiSpeechGrammar.kt`,
  `mobile_app/lib/app/voice_kernel/vision_voice_kernel_v3.dart`,
  `mobile_app/lib/app/assistant_session_controller.dart`, `docs/assistant.md`
- Related requirements: FR-013 through FR-019, NFR-OFFLINE-002, NFR-SEC-003,
  NFR-REL-001, NFR-MAINT-001, BR-003

## ADR-044: Keep One Foreground Command Session Active Until Goodbye

- Date: 2026-08-20
- Status: Accepted; refines the bounded one-command window in ADR-042/043
- Context: Owner testing confirmed clear recognition but found wake-before-every-
  command interaction unprofessional. The Document Scanner's Dart resolver also
  contained substantially more semantic aliases than its constrained native
  Vosk graph, so many valid UI actions could never reach the resolver.
- Options considered: require wake for every command; use an arbitrary inactivity
  timeout; leave the full conversation graph active; keep a focused foreground
  command graph active until an explicit goodbye.
- Decision: One complete branded wake opens an explicit foreground command
  session. Resume the contextual app/scanner graph after commands, feedback,
  rejected input, and bounded decoder timeouts. Only an offline goodbye (or the
  user disabling/stopping hands-free mode) ends the session and restores the
  wake-only graph. Preserve Smart AI “bye” as a return to the active offline
  session. Keep background/lock suspension and final-only wake activation.
  Expand the Scanner graph to the deterministic capture, playback, speed,
  spelling, copy, camera, torch, navigation, and exit actions already exposed
  by the native Flutter UI, including bounded polite phrase variants.
- Rationale: This provides natural follow-up control without exposing an open
  full-vocabulary app-control path. Contextual grammars, `[unk]`, deterministic
  authorization, TTS echo rejection, and explicit goodbye retain safety bounds.
- Consequences: The active session listens longer and therefore requires a
  false-command/noise and battery matrix on the target phone. It remains an
  in-app foreground assistant, not background or OS-wide voice control.
- Related files:
  `mobile_app/lib/app/voice_kernel/vision_voice_kernel_v3.dart`,
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiSpeechGrammar.kt`,
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/OnDeviceSpeechRecognizerHandler.kt`,
  `mobile_app/lib/features/ocr_scanner/presentation/ocr_scanner_screen.dart`
- Related requirements: FR-013 through FR-015, FR-019, NFR-OFFLINE-002,
  NFR-REL-001, NFR-MAINT-001, BR-003

## ADR-045: Unify Document Reader Voice and Touch Actions

- Date: 2026-08-20
- Status: Accepted
- Context: Physical use showed that recognized reader commands could still fail
  because the UI Pause path also called Stop, stopped playback changed the voice
  context to Scanner Capture, command-result TTS cancelled newly started reader
  TTS, and final/numbered-line actions did not exist.
- Options considered: add more phrases only; maintain separate voice/UI paths;
  use the optional AI backend for reader interpretation; route every reader
  action through one typed local player request path.
- Decision: Keep reader control deterministic and offline. Use typed
  `OcrActionRequest` events, including an optional one-based line number, and
  execute both voice and visible controls through `AccessibleTextPlayer`. Keep a
  loaded document in Scanner Reading context after Stop. Do not speak separate
  assistant feedback for actions that immediately start document TTS. Treat
  “last line” as the final line, expose first/final/direct-line domain intents,
  and spell the complete selected line. Keep numeric speech bounded to 1-100 in
  the focused native graph while accepting 1-999 in deterministic Dart input.
- Rationale: One action path prevents behavior drift, avoids single-engine TTS
  cancellation, supports predictable TalkBack controls, and retains the focused
  grammar's lower-noise boundary.
- Consequences: OCR reading “lines” remain normalized sentence-like reading
  units rather than exact photographed layout rows. Physical multi-line,
  TalkBack, large-text, noise, and grammar-switch acceptance remains required.
- Related files: `mobile_app/lib/domain/services/accessible_text_player.dart`,
  `mobile_app/lib/domain/enums/voice_intent.dart`,
  `mobile_app/lib/app/providers.dart`,
  `mobile_app/lib/app/voice_kernel/command_executor.dart`,
  `mobile_app/lib/domain/services/intelligent_intent_resolver.dart`,
  `mobile_app/lib/features/ocr_scanner/presentation/ocr_scanner_screen.dart`,
  `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/VisionAiSpeechGrammar.kt`
- Related requirements: FR-013, FR-015, NFR-ACC-001, NFR-ACC-002,
  NFR-OFFLINE-002, NFR-MAINT-001, NFR-MAINT-002

## ADR-046: Prefer Authenticated Phone Audio for Wearable Priority Alerts

- Date: 2026-08-20
- Status: Accepted; supersedes the default-feedback-owner portion of ADR-033
- Context: The owner requested a Raspberry Pi and phone on the same local
  network, one Connect action that starts detection, and all detection audio
  through the phone speaker. Uncommitted work attempted to achieve one-click
  setup by embedding a Pi SSH password and adding an unauthenticated manual-IP
  WebSocket path.
- Options considered: keep Pi-only speech; stream frames to the phone; package
  SSH credentials and bypass pairing; send only bounded authenticated priority
  events to the phone while retaining Pi speech as disconnect fallback.
- Decision: Configure the UI for `10.141.17.148:8765`, retain mDNS/manual
  private-host fallback, and require the existing short-code/HMAC/Keystore
  pairing. After the one-time pair, `Connect & Start Detection` authenticates,
  synchronizes settings, and starts assistance in one action. The Pi keeps all
  camera/model inference local. Its stability/cooldown/rate policy targets the
  authenticated connected phone for priority audio; Flutter routes that event
  through `VisionVoiceKernelV3`, the single microphone/TTS owner. Pi-local
  speech is the fallback after phone disconnect. Remove the SSH dependency,
  embedded login password, and unauthenticated manual endpoint path.
- Rationale: This provides the requested phone-speaker experience without
  camera transport, duplicate speech, credential exposure, or loss of protocol
  authentication. Reusing the voice kernel coordinates recognition and TTS.
- Consequences: First use cannot truthfully be one tap because the owner must
  enter a fresh local pairing code. Later sessions are one action. Phone audio
  requires a live authenticated foreground connection; background/disconnect
  uses Pi speech if available. “Same internet” is insufficient when LAN client
  isolation or different routed subnets prevent peer access. Physical Pi,
  phone-speaker, TalkBack, reconnect and performance acceptance remain open.
- Related files: `mobile_app/lib/app/wearable_controller.dart`,
  `mobile_app/lib/app/wearable_phone_feedback_service.dart`,
  `mobile_app/lib/features/raspberry_pi/presentation/raspberry_pi_screen.dart`,
  `raspberry_pi/src/ai_blind_pi/feedback.py`,
  `raspberry_pi/src/ai_blind_pi/service.py`, `docs/wearable-protocol.md`
- Related requirements: FR-008, FR-010, FR-011, FR-017, NFR-OFFLINE-001,
  NFR-SEC-001 through NFR-SEC-004, NFR-REL-001, NFR-MAINT-001

## ADR-047: Exclusive Code-Free First-Phone Enrollment

- Date: 2026-08-20
- Status: Accepted; supersedes ADR-046 only for the first-use pairing UX
- Context: The owner requested connection without any displayed pairing code
  and supplied a Linux login. Packaging or retaining that login on Android
  would expose a device secret; removing authentication entirely would allow
  arbitrary LAN control.
- Options considered: embed SSH username/password; accept unauthenticated
  commands; retain manual short codes; use exclusive trust-on-first-use that
  issues a random revocable application credential to the first phone only.
- Decision: The production UI exposes one `Connect & Start Detection` action.
  An explicitly enabled, unclaimed Pi accepts one atomic
  `enrollment_request` from a private/loopback peer, returns a random credential
  once, and immediately closes enrollment while any credential remains active.
  Android protects the credential with its existing Keystore adapter; every
  later session retains nonce-bound HMAC authentication, replay controls and
  signed commands. Linux login credentials never enter Flutter source, Android
  storage, protocol messages, tests, logs, or tracked documentation. Legacy
  short-code protocol support remains non-UI compatibility only.
- Rationale: This meets the no-code interaction request while preserving
  authenticated control and avoiding reusable administrator credentials in a
  reverse-engineerable APK.
- Consequences: First enrollment is trust-on-first-use, so it must occur on an
  isolated owner-controlled router/hotspot. A different LAN client could claim
  an unclaimed Pi first. Lost/offline phone credentials require the owner to run
  local `ai-blind-pi revoke all` before reenrollment. The phone and Pi must still
  be on one reachable non-isolated LAN; this does not solve the current subnet
  blocker.
- Related files: `mobile_app/lib/infrastructure/networking/`,
  `mobile_app/lib/features/raspberry_pi/presentation/raspberry_pi_screen.dart`,
  `raspberry_pi/src/ai_blind_pi/security.py`,
  `raspberry_pi/src/ai_blind_pi/websocket_server.py`,
  `raspberry_pi/config/wearable.env.example`
- Related requirements: FR-010, FR-011, FR-017, NFR-OFFLINE-001,
  NFR-SEC-002, NFR-SEC-004, NFR-MAINT-001, NFR-MAINT-002

## ADR-058: mDNS Hostname Default and SSH Reverse Tunnel for Public-WiFi

- Status: Accepted
- Context: The Pi's DHCP address changes every time it connects to a new
  network, making the previously hardcoded IP `10.141.17.148` in
  `WearableDefaults.host` unreliable. The Pi hostname `rpi3-ml` is fixed by
  the OS install and never changes. Additionally, university/public WiFi
  networks often enforce client isolation, blocking mDNS between devices even
  on the same SSID.
- Decision:
  1. Replace the hardcoded IP with `rpi3-ml.local` as the default. Android NSD
     resolves `.local` mDNS names automatically on non-isolated LANs. The Pi
     already advertises `_aiba-wearable._tcp.local.` via `MdnsAdvertiser`.
  2. Add `raspberry_pi/scripts/reverse_tunnel.sh` — a POSIX shell script that
     opens an SSH reverse tunnel from the Pi's port 8765 to the owner's laptop
     port 8765 (`autossh` preferred, `ssh -N -R` fallback, `BatchMode=yes`).
     When client isolation blocks mDNS, the user runs the tunnel and enters the
     laptop's private LAN IP in the app host field instead.
  3. Add `raspberry_pi/systemd/ai-blind-assistant-tunnel.service` — disabled by
     default, opt-in for users who want the tunnel to start automatically.
  4. Tunnel target is validated to be a private/loopback address; the script
     rejects public internet addresses at runtime.
- Consequences:
  - The phone connects to the Pi on any owner-controlled LAN without IP
    management.
  - On public WiFi the user performs one extra setup step (run tunnel script,
    enter laptop IP) which is documented in the app UI and in the env file.
  - No credentials, IPs, or SSH passwords are stored in Android or Flutter.
  - The tunnel operates entirely within a private LAN; port 8765 is never
    forwarded to the internet.
  - Protocol v1 is still authenticated but unencrypted; the restriction to
    private LAN remains mandatory.
- Verification: `WearableDefaults.host` set to `rpi3-ml.local`; tunnel script
  and systemd unit present; in-app guidance card added; Flutter suite 318/0,
  Pi suite 15/0, analyzer 0 findings.
- Related files: `mobile_app/lib/core/constants/wearable_defaults.dart`,
  `raspberry_pi/scripts/reverse_tunnel.sh`,
  `raspberry_pi/systemd/ai-blind-assistant-tunnel.service`,
  `raspberry_pi/config/wearable.env.example`,
  `mobile_app/lib/features/raspberry_pi/presentation/raspberry_pi_screen.dart`

