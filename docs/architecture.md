# Architecture

Last reviewed: 2026-08-09

## Architectural Style

AI Blind Assistant uses a feature-first, layered native Flutter architecture:

- `features/`: screens and feature-local presentation widgets;
- `app/`: bootstrap, routing, themes, Riverpod state and orchestration;
- `domain/`: Flutter-independent entities, enums, repositories, and service
  interfaces;
- `infrastructure/`: Android/camera/model/storage/TTS/vibration adapters;
- `core/`: reusable accessibility, lifecycle, error, logging, result, constants,
  and widget foundations.

Presentation may depend on application and domain abstractions. Application may
depend on domain abstractions. Domain does not import Flutter, camera, LiteRT,
TTS, vibration, storage, or Raspberry Pi networking packages. Infrastructure
implements domain interfaces. Widgets do not initialize platform services.

## Current Source Structure

```text
mobile_app/lib/
  main.dart
  app/
    bootstrap.dart
    app.dart
    router/
    theme/
    *_providers.dart
    assistance_controller.dart
  core/
    accessibility/
    constants/
    errors/
    lifecycle/
    logging/
    result/
    widgets/
  domain/
    entities/
    enums/
    repositories/
    services/
  features/
    startup/presentation/
    home/presentation/
    permissions/presentation/
    mode_selection/presentation/
    mobile_assistance/presentation/
    raspberry_pi/presentation/
    settings/presentation/
    help/presentation/
    about/presentation/
  infrastructure/
    camera/
    detection/
    device/
    feedback/
    inference/
    storage/
    networking/       # authenticated local wearable protocol and transport
```

## State Management and Dependency Injection

Riverpod is the only state-management and dependency-injection mechanism.
Infrastructure services are provided through their domain interfaces so tests
can replace camera, inference, TTS, vibration, permission, and storage without
hardware.

Important mappings:

| Domain abstraction | Infrastructure implementation |
|---|---|
| `PermissionService` | `AndroidPermissionService` over MethodChannel |
| `SettingsRepository` | `LocalSettingsRepository` over SharedPreferences |
| `CameraService` | `MobileCameraService` over the Flutter camera package |
| `InferenceService` | `TfliteInferenceService` over MethodChannel |
| `DetectionPostProcessor` | `YoloPostProcessor` |
| `RiskAssessor` | `ObstacleRiskAssessor` |
| `TtsService` | `FlutterTtsService` |
| `VibrationService` | `DeviceVibrationService` |
| `AlertOrchestrator` | `FeedbackAlertOrchestrator` |
| `WearableDiscoveryService` | Android NSD MethodChannel adapter |
| `WearableCredentialRepository` | Android Keystore AES-GCM MethodChannel adapter |
| `WearableTransport` | `WebSocketWearableTransport` |
| `WearableRepository` | authenticated WebSocket repository |

`AssistanceController` is a Riverpod Notifier and the sole Mobile Mode session
orchestrator. Feature widgets render its state and call intent methods; they do
not sequence services themselves.

## Routing

`MaterialApp.onGenerateRoute` uses centralized definitions in
`app/router/`. Widgets navigate with route constants rather than scattered
string literals.

| Route | Purpose |
|---|---|
| `/startup` | project identity and offline/privacy entry |
| `/home` | current mode and assistance actions |
| `/modes` | Mobile/Pi mode selection |
| `/mobile-assistance` | camera, detections, alerts, start/stop/recovery |
| `/raspberry-pi` | local wearable discovery, pairing, control, and status |
| `/settings` | local sensitivity and feedback settings |
| `/about-safety` | project limitations and safety boundary |
| `/help` | accessible quick-start guidance |

The UI remains native Flutter. Stitch HTML, remote assets, and rendered
screenshots are design references only; no WebView or production remote asset
loading is allowed.

## Mobile Mode State Machine

The visible states include idle, permission required/denied/permanently denied,
initializing camera, loading model, ready, detecting, paused, stopping, camera
error, model error, inference error, and feedback error.

```text
Start
  -> check/request camera permission
  -> initialize rear camera
  -> load and warm up bundled YOLOv8n
  -> mark Ready
  -> start image stream
  -> attach frame processing
  -> start selected feedback outputs
  -> Detecting
```

No assistance starts unless camera permission is granted and the model is
loaded. Each async startup uses a session generation token. Stop or lifecycle
pause invalidates late work so a disposed camera/model cannot revive itself.

Pause, inactive, detached, stop, runtime error, and disposal paths release the
camera stream/controller, interpreter/native executor work, detection state,
speech, and vibration. Resume does not silently restart assistance; the user
explicitly resumes it.

## Camera and Inference Boundary

Flutter camera callbacks deliver three copied YUV420 planes with row and pixel
strides, dimensions, timestamp, lens direction, and rotation. Frames are
limited to roughly 5 FPS before native inference. One native inference runs at
a time; extra frames are dropped instead of queued.

The existing Android MethodChannel hands transient frame data to
`InferenceHandler`, which owns:

- a background executor;
- LiteRT model/interpreter load, actual tensor inspection, warm-up, and close;
- stride-aware YUV-to-RGB conversion;
- rotation and front-camera mirroring;
- aspect-preserving letterbox resize with RGB 114 padding;
- tensor creation using the actual input layout/type;
- reusable direct buffers and two CPU threads;
- output dequantization and transform metadata.

The final model is float32 NCHW `[1,3,320,320]` to float32
`[1,84,2100]`. CPU/XNNPACK is the verified default and safe fallback. Hardware
delegates remain disabled until device-specific correctness and fallback are
tested. Full details are in [model-integration.md](model-integration.md).

## Detection, Risk, and Feedback

```text
RawInferenceOutput
  -> YoloPostProcessor
  -> DetectionStabilizer
  -> ObstacleRiskAssessor
  -> FeedbackAlertOrchestrator
  -> local TTS and/or bounded vibration
```

`YoloPostProcessor` validates tensor metadata, applies sensitivity-controlled
confidence filtering, decodes normalized YOLO boxes, removes letterbox padding,
maps to preview coordinates, and performs per-class NMS.

`DetectionStabilizer` requires two spatially matching processed frames.
`ObstacleRiskAssessor` uses relative box size/location and class importance,
never metric distance. `FeedbackAlertOrchestrator` selects one highest useful
alert, applies cooldown/duplicate/global rate rules, allows urgent risk-upgrade
interruption, and honors saved audio/vibration modes.

## Local Storage

Non-sensitive application settings are stored with SharedPreferences:

- operating mode;
- detection sensitivity/confidence preference;
- feedback mode and vibration enablement;
- announcement cooldown;
- related validated local settings.

The paired wearable endpoint is stored with its encrypted credential so it can
be restored after Android process recreation. The secret is encrypted with
AES-GCM under a non-exportable Android Keystore key and Android backup is
disabled. The Pi stores a protected derived verifier and bounded configuration.

Camera frames, detection histories, images, video, faces, audio, analytics
identifiers, and user profiles are not stored.

## Accessibility Architecture

- Every route exposes a meaningful title.
- Primary controls use native Flutter buttons with semantic labels.
- Selectable settings expose selected state.
- Assistance status and current alerts use semantic live regions.
- Important state is conveyed through text and semantics, not color alone.
- Shared touch-size and typography tokens support large text.
- Persisted high-contrast, large-text, and reduced-motion preferences are
  applied once at the root app boundary rather than reimplemented by screens.
- Layouts are SafeArea-aware and scroll where required.
- Alert cadence is deliberately bounded to avoid TalkBack/TTS overload.
- Help and About keep safety limitations reachable.

Automated semantics and 2.0 text-scale tests pass. Physical TalkBack and Android
font/display scaling remain manual acceptance requirements.

## Privacy and Offline Boundaries

- The model, labels, and metadata are bundled assets.
- Production has Android network permission solely for authenticated local-LAN
  Wearable Mode. It contains no cloud endpoint or runtime model downloader.
- No runtime downloader, Firebase, cloud inference, user accounts, analytics,
  remote configuration, or crash-reporting service is present.
- Camera frames and image bytes are never logged, stored, or uploaded.
- TTS uses the installed Android engine; microphone permission is not requested.
- Raspberry Pi traffic contains compact typed status/detection events; normal
  operation never streams raw frames. Protocol v1 authentication/integrity does
  not add confidentiality, so pairing is restricted to a trusted private LAN.

## Error and Logging Rules

Platform failures are translated into safe assistance states and user-readable
messages. Failures are not silently ignored. Partial feedback failure becomes a
visible warning when another selected output still works; total selected-output
failure stops the session safely.

`SafeDebugLogger` remains debug-only and must never receive frames, image bytes,
face data, audio recordings, identifiers, secrets, or full local file content.

## Testability

Pure parsing, stability, risk, cooldown, settings, state transitions, and UI
semantics are automated through injected fakes. Android emulator evidence covers
the packaged model/camera/lifecycle/offline smoke path. Physical sensor,
TTS/haptic, TalkBack, alignment, performance, memory, battery, and thermal
behavior remain explicit manual checks.

## Raspberry Pi Wearable State Machine

The owner explicitly authorized the isolated wearable module in ADR-031. One
Riverpod `WearableController` owns Flutter intent and lifecycle, while one
repository owns discovery/pairing/transport/protocol state:

```text
notConfigured -> discovering -> deviceFound -> pairing -> paired
  -> connecting -> authenticating -> connected
  -> starting -> running <-> paused -> stopping -> connected
```

Explicit incompatible, authentication-failed, unavailable, disconnected,
reconnecting, and error states carry recovery guidance. Important commands have
correlated acknowledgements. Heartbeats and a bounded exponential retry policy
detect and recover temporary loss without a tight retry loop.

Backgrounding closes only the phone transport; it does not send a stop command.
The Pi service owns its running camera/model session and local feedback, so
essential assistance continues without the phone. On resume the phone restores
the desired authenticated connection and resolves settings by version before
accepting telemetry.

The Pi service loads one Open Images V7 NCNN model, uses a single camera with a
latest-frame bounded queue, and never installs PyTorch. Its component adapters
are injected so the same protocol/state path runs with a hardware-free
simulator. Full details are in [wearable-mode.md](wearable-mode.md) and
[wearable-protocol.md](wearable-protocol.md).
