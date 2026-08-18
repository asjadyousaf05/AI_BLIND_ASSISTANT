# Architecture

Last reviewed: 2026-08-14

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
    assistant/presentation/
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
    assistant/        # on-device speech, microphone, HTTP, Keystore and TTS
```

### Assistant Service Boundary

ADR-039 authorizes the in-app assistant, ADR-041 requires phone-local speech,
and ADR-042 authorizes foreground hands-free wake activation. Flutter owns user
intent, confirmation, lifecycle policy, secure pairing credentials, action
execution, deterministic parsing, and spoken UI output. The bundled Vosk model
owns foreground wake/command transcription on supported Android releases. Its
idle recognizer uses a constrained “Hey Vision AI” grammar; after a match, the
paused recognizer resets to Vosk's default graph for the bounded command or
confirmation window and returns to the wake grammar after TTS.
Manual push-to-talk prefers Android's dedicated API 31+ recognizer and falls
back to Vosk. The optional paired laptop owns unmatched general-conversation
reasoning and local personal utilities. Common controls bypass models; all
model tool suggestions pass through a strict allow-list before Flutter maps
them to real controllers and verifies state.

The laptop prefers Gemini only when an environment key is configured and falls
back to Ollama per request. Gemini receives typed/transcribed text only with
`store:false`. Camera frames and raw recordings never enter Gemini requests.
The assistant cannot run arbitrary code or control Android outside this app.
Typed and spoken app controls do not require an assistant credential or backend
health check. Only unmatched general-conversation text requires the
authenticated private-LAN laptop.

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
| `MicrophonePermissionService` | native Android permission MethodChannel |
| `OnDeviceSpeechRecognitionService` | dedicated Android API 31+ on-device recognizer MethodChannel |
| `AssistantCredentialRepository` | Android Keystore AES-GCM MethodChannel adapter |
| `AssistantRepository` | authenticated private-LAN HTTP repository |
| `SpeechOutputService` | `FlutterTtsSpeechOutputService` |

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
| `/assistant` | foreground hands-free, typed/manual voice conversation, status, and confirmation |
| `/assistant/connection` | trusted private-laptop host and pairing code |
| `/assistant/settings` | assistant privacy, connection, and local-data controls |

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

Assistant and Wearable bearer credentials are encrypted with AES-GCM using
non-exportable Android Keystore keys. Legacy assistant preference credentials
are migrated and removed. The laptop stores token hashes/auth records and only
explicit notes/reminders/schedules/preferences in local SQLite. General
conversation-body persistence is disabled by default.

The paired wearable endpoint is stored with its encrypted credential so it can
be restored after Android process recreation. The secret is encrypted with
AES-GCM under a non-exportable Android Keystore key and Android backup is
disabled. The Pi stores a protected derived verifier and bounded configuration.

Camera frames, detection histories, images, video, faces, assistant recordings,
analytics identifiers, and user profiles are not stored. Bounded audio exists
only in phone/backend temporary files until request/transcription cleanup.

## Accessibility Architecture

- Every route exposes a meaningful title.
- Primary controls use native Flutter buttons with semantic labels.
- Selectable settings expose selected state.
- Assistance status and current alerts use semantic live regions.
- Important state is conveyed through text and semantics, not color alone.
- Route titles use semantic heading level 1 and section titles use level 2.
- Shared touch-size and typography tokens support large text.
- Persisted high-contrast, large-text, and reduced-motion preferences are
  applied once at the root app boundary rather than reimplemented by screens.
- Large-text preference scaling composes with, rather than replaces, Android's
  potentially nonlinear platform `TextScaler`, and is capped at 2.5.
- Layouts are SafeArea-aware and scroll where required.
- Alert cadence is deliberately bounded to avoid TalkBack/TTS overload.
- Help and About keep safety limitations reachable.

Automated semantics, 2.0 text-scale, and Flutter Android tap-target, label and
contrast guideline checks pass. Physical TalkBack and Android font/display
scaling remain manual acceptance requirements.

## Privacy and Offline Boundaries

- The model, labels, and metadata are bundled assets.
- Android network permission supports authenticated local-LAN Wearable and
  assistant connections. Core Mobile Mode contains no network dependency or
  runtime model downloader.
- The release has no Firebase, analytics, remote configuration, crash reporting,
  cloud vision, account service, or camera upload. Optional Gemini is a bounded
  text-reasoning exception disclosed in the assistant UI.
- Camera frames and image bytes are never logged, stored, or uploaded.
- TTS uses the installed Android engine. Microphone permission is granted once
  for foreground hands-free or manual voice. The listener stops when the app is
  backgrounded/locked and restarts when the foreground app resumes. Recognition
  is paused during TTS. App-command audio is not uploaded or stored by the app.
- Raspberry Pi traffic contains compact typed status/detection events; normal
  operation never streams raw frames. Protocol v1 authentication/integrity does
  not add confidentiality, so pairing is restricted to a trusted private LAN.
- Assistant environment/database files are ignored. API keys remain backend
  environment secrets and are never packaged in Android.
- Assistant HTTP is authenticated but unencrypted; restrict port 8765 to a
  trusted private LAN and never expose it publicly.

## Error and Logging Rules

Platform failures are translated into safe assistance states and user-readable
messages. Failures are not silently ignored. Partial feedback failure becomes a
visible warning when another selected output still works; total selected-output
failure stops the session safely.

`SafeDebugLogger` remains debug-only and must never receive frames, image bytes,
face data, audio recordings, identifiers, secrets, or full local file content.

## Testability

Pure parsing, stability, risk, cooldown, settings, providers, command/tool
validation, state transitions, and UI semantics are automated through injected
fakes. Bundled Vosk, exact wake matching, the dedicated/manual channel, and the
no-remote-fallback controller path have automated evidence; local Ollama and authenticated backend paths have live host
evidence. Physical sensor/microphone, TTS/haptic, TalkBack, live Gemini,
alignment, performance, memory, battery, and thermal behavior remain explicit
manual checks.

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
