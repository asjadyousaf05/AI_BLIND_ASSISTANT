# Architecture

## ADR-076 implementation — 2026-10-21

The existing Riverpod voice kernel remains the single microphone/action owner.
Strict native resume acknowledgement reaches the infrastructure adapter; cleanup
stays best effort. The application coalesces starts/recovery, serializes native
recognition events and invalidates stale lifecycle work. Recovery is bounded to
two attempts before an actionable error; an existing settings screen invokes the
kernel's explicit restart. Domain capability `VoiceListeningFeedback` optionally
requests local readiness output through the same recognition adapter; domain stays
independent of Flutter/Android. The native recognizer owns a separate bounded
Vision AI cue session, while MainActivity forwards foreground state. Smart AI's
cue/recorder/provider implementations retain their ownership. No new screen,
route, dependency, model, network request or audio retention. Resolver changes
reject missing/negated speech and apply ASR repairs on whole words.
[Decision](decision-log.md), [verification](VISION_AI_RELIABILITY_2026-10-21.md).

## ADR-075 implementation — 2026-10-21

Keep the existing feature-first/Riverpod/central routes architecture. Assistant
presentation restores bounded saved-mode state, preserves saved Gemini/laptop
selection and renders the existing circle in a setup state for fresh users. The
existing Smart AI controller acquires only local audio/commands before cloud
configuration; client/recorder initialization and start/hold/send stay gated.
Widgets invoke controllers, retain unsent drafts and show accurate disabled/setup
semantics. No new domain types, backend, native bridge, recognizer, thread or
provider. [Decision](decision-log.md) and [verification](SMART_AI_FRESH_PHONE_2026-10-21.md).

## ADR-074 implementation — 2026-10-21

Keep the feature-first/Riverpod/central-routes architecture. AppRouteObserver
notifies the existing kernel after Navigator build; visible routes override stale
screen cleanup, with remembered scanner capture/reading context for restoration.
The pure resolver and shared registry scope short verbs/manual controls. Executor
progress callbacks use the same speech/echo owner without reopening the microphone
mid-action; final messages inspect controller state. Smart AI's existing coordinator
opens direct local command sessions, yields AudioRecord for explicit capture and
restores the saved preference. Its pre-command cancellation restores reply locale;
idle/paused release cannot silence newer local feedback. No extra service/thread,
provider, domain dependency on UI or hardware initialization in widgets. See
[ADR-074](decision-log.md) and [verification](VISION_AI_COMMANDS_2026-10-21.md).

## Module 72: Isolated Smart AI microphone-ready feedback

ADR-073 replaces only SmartAiRecordingCue's vibrator-plugin call with a private
native method channel. The existing audio coordinator/domain boundary triggers
play after recorder success and stop on cancel/submit/release; the Riverpod
controller keeps capture usable and exposes partial hardware failure guidance.
Widgets only invoke controller operations and provide labelled instructions.

MainActivity registers SmartAiRecordingCueHandler and forwards foreground/pause/
destroy. The handler uses Android accessibility-classified Vibrator output and
a bounded local ToneGenerator prompt on the unchanged media stream/volume.
SmartAiCueSession independently attempts both outputs and guards delayed cleanup
by generation. Native resources release after 300 ms or cancellation; channel
calls have 750 ms deadlines. No new dependency, permission, file/remote asset,
thread, routing or shared Vision AI implementation. See
[verification](SMART_AI_READY_CUE_2026-10-21.md).

## Module 71: Smart AI circle and foreground local controls

ADR-072 adds a pure per-turn English/Urdu/goodbye policy and an isolated callback-
only circle with semantic/keyboard activation. The existing Smart AI Riverpod
controller owns hold generations, release/cancel, local playback pause state,
recording-language choice, guide speech and audio-before-Home exit ordering.
Domain audio coordination gains capture handover and local goodbye events.

An optional SmartAiForegroundRecognition capability is implemented by the
existing Android speech adapter/native handler. While the Smart AI screen is
foreground, append exact branded goodbye phrases to the unchanged base local
wake/app grammar, emitting a separate event without a wake prefix. No partial
result executes it; speaker echo and incidental phrases are rejected. A narrow
kernel button-mode flag selects app controls and forbids automatic legacy
conversation; ordinary Vision AI behavior outside this mode remains unchanged.
Native AudioRecord yields during button capture and resumes afterwards. On exit,
restore the saved global hands-free preference without rewriting it.

SmartAiRecordingCue uses the existing vibration dependency for one 180 ms pulse,
with default amplitude for devices lacking amplitude control. It is independent
of detection-alert preferences. The localized Smart AI speech adapter uses shared
sentence progress and echo-guard ownership, bounded chunks and a suspended future
to resume at the last reported word; it restores en-US on pause/cancel/exit.
The shared TTS implementation, Vision AI base grammar/resolver, detection, backend
and Pi remain unchanged. No new worker, package, route or recorder format.

HTTP keeps the exact base prompt first, latest-turn language instruction second,
and bounded history. Auto leaves Whisper language unspecified; explicit en/ur
uses the existing multipart request and is frozen through that turn's answer.
Spoken guidance, named language/control buttons, listener status and Home exit
are presentation over controller/domain operations. See
[verification and physical limits](SMART_AI_CIRCLE_2026-10-20.md).

## Module 70: Smart AI-only cloud audio

`SmartAiCloudController` is independent of the existing shared assistant and
Vision AI controllers. Its Riverpod-injected domain interfaces cover personal
configuration, Groq/AgentRouter transport and local audio coordination. The
existing Smart AI route selects an isolated cloud view only after opt-in;
Connect Assistant embeds a separate credential card. No new route, package,
native handler, Vision AI implementation or backend service is introduced.

ADR-071's 20 October follow-up adds a Smart AI-only reply-speech interface and
localized adapter, injected through Riverpod. It selects installed offline Urdu
or English voices around the existing shared speech owner and restores en-US
before exit. Serialized selection/cancellation prevents late voice changes.
No shared recognizer, reader or Vision AI implementation is edited. A retained
answer can be replayed locally without a cloud call.

The new recorder adapter reuses the existing native 16 kHz mono AAC/M4A channel
with its own cache subdirectory/prefix. A Smart AI-only method on the existing
recorder handler resolves Android's private cache directory; recording format
and the other native recorder methods are unchanged. The controller reacquires
audio ownership immediately before capture, including after permission prompts.
After capture, fixed HTTPS Groq multipart upload
produces a transcript; deterministic controls run locally before unmatched
conversation goes to the requested AgentRouter model. The exact owner prompt,
six-message bound and 220-token cap favor concise spoken replies. The request
uses an explicit upstream DeepSeek non-thinking option; the gateway's
support remains a live acceptance gate. HTTP 400/422 errors report request
compatibility, 402 credit, 413 size and 408/504 gateway timeout; other failures
retain bounded safe messages without provider diagnostic-body disclosure. TTS
uses the existing audio owner. Wake listening is paused only for this screen
and restored from the existing preference on exit; no preference is rewritten.
Audio acquisition/restoration, recording, transcription, reasoning and speech
are sequential and cancellable. Late/background results cannot speak. Clips
are deleted before reasoning, including failure/cancellation, and next capture
removes only this feature's orphan cache files. No model tools are executed.
See ADR-070 and [verification/setup](SMART_AI_CLOUD_AUDIO_2026-10-19.md).

## Module 69: Personal Gemini and shared phone hotspot

ADR-069 adds `GeminiConfigurationRepository` and `GeminiConversationService`
domain interfaces. Infrastructure uses the existing Android Keystore channel
under an independent storage key and a fixed Google HTTPS text-only endpoint.
Riverpod injects both into the existing assistant session controller. The
existing Connect Assistant screen contains an opt-in personal-key form; no
new route/state-management system is introduced. Direct mode bypasses laptop
health/pairing and uses phone-local recognition even with saved laptop trust.
Responses are plain text, never decoded as app tools. Request generations and
transport cancellation reject late background replies. Mode changes clear
conversation memory; keys are redacted in diagnostics and excluded from APKs.
This is the owner's explicit personal-key exception to older backend-only key
storage wording elsewhere below. Core inference and controls remain local.

Both laptop and Pi may join the phone hotspot. The phone is the access point;
it need not also be a Wi-Fi station. Pi NSD/secure WebSocket and laptop HTTP
use their respective current DHCP addresses; their common port 8765 does not
conflict because they run on different hosts. Cellular internet is required
only for optional Gemini, not local Pi/Ollama assistance.

## Module 68: Approved Smart AI speech boundary

The owner's 2026-10-16 approval permits the existing paired Smart AI Speak
button to send a bounded temporary clip only to the authenticated private-LAN
laptop for local Whisper medium. The screen explains this before Speak; both
devices delete their temporary clips after processing, including failure paths.
Gemini receives text only. Hands-free/wake and unpaired manual recognition stay
phone-local. ADR-068's addendum supersedes ADR-043 only for paired manual Smart
AI; Riverpod, domain interfaces, deterministic routing and named routes remain.

## Module 67: Reader speech and guarded interruption

The Scanner reports playback to the injected voice kernel. With foreground
hands-free already enabled, playback opens contextual controls while honoring
explicit dismissal. Native Vosk exposes stable multiword proposals only during
reader playback in its scanner graph; it does not execute them. Dart requires
a strong registered reversible reader intent, current context/session and no
current/recent text echo. A native atomic, expiring claim pauses the decoder
before the existing executor handles the command. Other actions retain final
recognition. See ADR-067.

One speech-output adapter reclaims the shared engine's handlers/completion mode
per turn. An awaited result and cancellation signal belong to that turn;
unidentified global cancel/completion events cannot complete its replacement.
Progress text and reader utterance/generation checks reject stale updates.
Echo protection retains a bounded in-memory sentence tail, including stop and
completion. Acoustic cancellation is still device-dependent, not a software
claim of speaker identification or complete echo removal.

## Module 66: Scanner commands and Smart AI entry

The owner's later framing request supersedes immediate rescan capture:
explicit voice rescan/restart now reuse Scan Another Page's reset/framing path.
A subsequent explicit Scan command/button captures the repositioned document;
there is no automatic capture timer. Scanner camera ownership remains the
existing ISSUE-052 exception. See ADR-067's rescan addendum.
Dismissal is an exact, complete explicit request, including “goodbye” and
“stop listening”; bare “bye”/“by” and incidental sentence substrings cannot
end a session. Native grammar, Dart resolution and backend routing agree.

`AssistantBackendStatus` tracks saved-laptop reachability independently of the
voice session. Smart AI's screen-entry intent asks its injected controller to
load pairing and perform one shared, eight-second bounded health/version check.
Pairing changes and disposal invalidate old results. Entry/retry never sends a
question or OCR draft, and offline controls remain available during the check.
A reachable health endpoint is not proof of accepted credentials or available
reasoning providers. See ADR-066.

## Module 65: Wearable session and feedback boundaries

The repository stamps all authenticated commands and transport heartbeats at
one signing boundary, using one increasing sequence. It seeds a monotonic
session clock from the Pi hello, without changing system clocks or widening the
existing two-minute replay window. `ProtocolEnvelope` preserves the peer's exact
encoded timestamp for HMAC, including trailing fractional zeros. Pi canonical
JSON numbers follow Dart's decimal/exponent rendering; protocol v1 fields and
nonce/tag/replay checks remain unchanged. See ADR-065.

The injected phone-feedback interface offers announce, audio test and stop
through the existing single voice owner. Stop invalidates its speech generation
before platform work, preventing delayed utterances and duplicate microphone
resume. The wearable controller stops active speech on pause/stop, link loss,
background and mute; it rejects non-running/late alerts. A settings-sync failure
blocks the combined Start flow. Pi live settings change only after a successful,
serialized persistent write; local speech stops before phone-target feedback.

Pi mDNS uses only the selected private interface and closes resources if
registration fails. The NetworkManager Wi-Fi-up hook schedules restart without
blocking the dispatcher. Hotspot ownership, Keystore enrollment, Riverpod DI,
named routes, local inference and the camera-frame boundary are preserved.

## Module 64 audit corrections

ADR-064 retains the existing feature-first/Riverpod/routing architecture.
`BatteryStatusService` is a domain contract, injected through an Android
MethodChannel adapter. Widgets do not initialize the battery or network service.
Assistant HTTP uses only the explicitly paired private endpoint, validates DNS
results before connecting, disables redirects/proxies and closes through provider
disposal. Whole request/body time and response size are bounded; mutations are
not automatically retried across endpoints or after ambiguous failure.

Laptop pairing requires the owner-issued one-time code. One in-memory pending
server proposal per authenticated user binds confirmation to user/request/tool;
execution uses server-owned arguments. Cancel, replay, mismatch and superseding
queries cannot execute it. No new identity system, cloud processing or raw-frame
upload was introduced. Physical acceptance and Scanner camera layering debt
remain open. Exact evidence: PROJECT_AUDIT_2026-10-09.md.

## Module 61 wearable connection reliability

Riverpod holds one user action across discovery, trust, authentication, settings,
and detection start. Repository operation generations and cancellation signals
bound retries and reject work after disconnect/background/disposal. Transport
socket generation is reserved before asynchronous cleanup, preventing a late
socket opening. A separate session generation rejects late command state
changes. Foreground/current-device checks gate phone speech.

Trusted selections retain their credential. Manual re-addressing checks saved
credentials using the hello device ID, then authenticates normally. Each retry
rediscovers that device's current address, and hostname lookup has the handshake
timeout. Socket-error and status paths share one bounded reconnect run; auth
rejection is terminal and exhausted retries require explicit retry/resume.

Android NSD resolves a bounded queue serially on the main thread, retains the
multicast lock only for discovery, rejects old-session callbacks, and removes
only the discovery timeout. Personal Hotspot remains owner-configured. No
static hotspot address, camera-frame transfer, or new authentication scheme is
introduced. See ADR-061 and PHONE_HOTSPOT.md.

## Module 59 phone-hotspot network

The owner phone's Personal Hotspot is the primary private LAN for Pi Wearable
Mode. The Pi joins as a NetworkManager DHCP client. The phone discovers
`_aiba-wearable._tcp` with Android NSD and a discovery-scoped multicast lock;
the saved credential is associated with the Pi device ID and reconnect
discovery refreshes a changing address. `.local` and the current private
address are manual fallbacks, not proof that the DHCP address is stable.
The Pi's NetworkManager Wi-Fi-up dispatcher restarts the bounded systemd
service after the hotspot returns. See `PROJECT_GRAPH.md` and
`PHONE_HOTSPOT.md`. This path still needs real phone/Pi acceptance.

Last reviewed: 2026-10-15

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
ADR-042 authorizes foreground hands-free wake activation, ADR-043 requires safe
two-stage decoding and contextual Smart AI speech, and ADR-044 keeps one
foreground command session active until an explicit goodbye. Flutter owns user
intent, confirmation, lifecycle policy, secure pairing credentials, action
execution, deterministic parsing, and spoken UI output. The bundled Vosk model
owns foreground wake/command transcription on supported Android releases. Its
idle recognizer uses a constrained “Hey/Hi Vision AI” grammar and acts only on
final complete phrases. After a match, the paused recognizer uses a focused
app-command or scanner grammar and restores that contextual grammar after TTS,
rejected input, and decoder timeouts. An offline goodbye restores the wake-only
grammar. Profile changes cancel and join Vosk's
decoder thread before changing grammar; application code never replaces the
private recognizer in a running `SpeechService`.

Manual push-to-talk prefers Android's dedicated API 31+ recognizer and falls
back to Vosk. `VisionVoiceKernelV3` serializes manual and hands-free microphone
ownership. On `/assistant`, the same Vosk capture path selects the default
conversation graph and remains conversational in the visible foreground until
“bye”/“by” returns to the active offline command session. The optional paired
laptop owns unmatched
general-conversation reasoning and local personal utilities. Common controls bypass models; all
model tool suggestions pass through a strict allow-list before Flutter maps
them to real controllers and verifies state.

Document Reader voice and visible controls share a typed `OcrActionRequest`
path into `AccessibleTextPlayer`. Requests may carry a one-based line target;
the presentation layer clamps it to the loaded document. Reader actions that
start document speech return silent command results so assistant feedback
cannot cancel the new utterance on Android's single TTS engine.

Scanner camera capture uses a temporary local photo, deleted before playback
and on interrupted/error paths. The framing analyzer honors camera Y-plane row
and pixel stride. Manual torch choice holds for the current camera session.
`AccessibleTextPlayer` exposes speech failure and retry state. “Ask AI” opens a
disclosed, editable in-memory draft on the assistant route; only the user's
subsequent Send can pass recognized text to the optional paired laptop. The
Scanner presentation widget still directly owns camera-plugin lifecycle;
ISSUE-052 tracks the planned injected-service correction.

The laptop prefers Gemini only when an environment key is configured and falls
back to Ollama per request. Gemini receives typed/transcribed text only with
`store:false`. Camera frames and raw recordings never enter Gemini requests.
The assistant cannot run arbitrary code or control Android outside this app.
Typed and spoken app controls do not require an assistant credential or backend
health check. Unmatched general-conversation text uses the selected direct Gemini or
authenticated private-LAN laptop path (ADR-069).

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
| `WearablePhoneFeedbackService` | app adapter to the single `VisionVoiceKernelV3` TTS owner |
| `MicrophonePermissionService` | native Android permission MethodChannel |
| `OnDeviceSpeechRecognitionService` | bundled Vosk foreground wake/command/conversation plus dedicated Android API 31+ manual-recognition MethodChannel |
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
| `/raspberry-pi` | local wearable discovery, code-free enrollment, control, and status |
| `/settings` | local sensitivity and feedback settings |
| `/about-safety` | project limitations and safety boundary |
| `/help` | accessible quick-start guidance |
| `/assistant` | foreground hands-free, typed/manual voice conversation, status, and confirmation |
| `/assistant/connection` | personal Gemini opt-in or trusted private-laptop host and pairing code |
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

The trusted wearable endpoint is stored with its encrypted credential so it can
be restored after Android process recreation. The secret is encrypted with
AES-GCM under a non-exportable Android Keystore key and Android backup is
disabled. The Pi stores a protected derived verifier and bounded configuration.

Camera frames, detection histories, images, video, faces, assistant recordings,
analytics identifiers, and user profiles are not stored. Bounded audio exists
only in phone/backend temporary files until request/transcription cleanup.

## Accessibility Architecture

ADR-063 requires a single action name for custom button/choice semantics,
explicit accessibility activation, and separate selected/disabled flags.
Visible decorative captions are excluded when they would repeat that name.
Native switches, editable fields, icon-button tooltips and slider adjustment
semantics are retained. Cooldown label and seconds value merge into one node.
Reader playback names change with the action available in the current state.

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
  is paused during TTS. Hands-free/unpaired app-command audio stays on the phone.
  Paired Smart AI manual speech has the explicitly approved temporary laptop
  transcription exception above; clips are not retained after processing.
- Raspberry Pi traffic contains compact typed status/detection events; normal
  operation never streams raw frames. Only signed, stability/cooldown-gated
  priority events can request phone audio. Protocol v1 authentication/integrity
  does not add confidentiality. First-phone enrollment is exclusive,
  private-peer-only trust-on-first-use and is restricted to an
  owner-controlled private LAN.
- Assistant environment/database files are ignored. Laptop API keys remain backend environment secrets. ADR-069 permits a
  user-entered personal key encrypted by Android Keystore for direct mode;
  no key is embedded in the APK.
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
repository owns discovery/enrollment/transport/protocol state:

```text
notConfigured -> discovering -> deviceFound -> enrolling -> paired
  -> connecting -> authenticating -> connected
  -> starting -> running <-> paused -> stopping -> connected
```

Explicit incompatible, authentication-failed, unavailable, disconnected,
reconnecting, and error states carry recovery guidance. Important commands have
correlated acknowledgements. Heartbeats and a bounded exponential retry policy
detect and recover temporary loss without a tight retry loop.

Backgrounding closes only the phone transport; it does not send a stop command.
The Pi service owns its running camera/model session. An authenticated connected
phone is the preferred speech target; priority events are routed through the
same voice kernel that coordinates assistant TTS and microphone state. When the
phone disconnects or backgrounds, Pi-local speech becomes the fallback so the
Pi session can continue. On resume the phone restores the desired authenticated
connection and resolves settings by version before accepting telemetry.

The Pi service loads one Open Images V7 NCNN model, uses a single camera with a
latest-frame bounded queue, and never installs PyTorch. Its feedback policy
emits ordinary detections as silent telemetry and at most one bounded priority
target after stability, cooldown and rate gates. Its component adapters are
injected so the same protocol/state path runs with a hardware-free simulator.
Full details are in [wearable-mode.md](wearable-mode.md) and
[wearable-protocol.md](wearable-protocol.md).
