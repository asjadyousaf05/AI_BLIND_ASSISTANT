# AI Blind Assistant: Complete Project Guide and Viva Preparation

Prepared 22 October 2026, Asia/Karachi. Based on the current repository, dated verification records and the owner's latest physical-device feedback. This is a self-contained upload for GPT and a study guide for the project owner.

## 1. How to use this file with GPT

Upload this file and send the following instruction:

> Act as my patient project tutor and final-year-project examiner. Use this document as project context. First explain the project in simple English, then teach the architecture, technologies, detection pipeline, Raspberry Pi networking, voice commands, OCR, Smart AI, security and testing step by step. Explain technical terms with examples. If I ask, explain in Urdu or Roman Urdu while keeping technical names in English. Distinguish implemented code, recorded tests, owner-confirmed behavior, missing evidence and future work. Do not invent training runs, datasets, accuracy, benchmarks, user studies or deployment results. Correct any claim that export, threshold adjustment or ordinary image testing is model fine-tuning. After each topic, ask me one viva question and help improve my answer. Keep model names and processing locations distinct. Use the evidence dates in this file; do not imply these measurements describe every later session.

Useful follow-up requests:

- “Teach me the project as if I am a beginner, one topic at a time.”
- “Explain exactly what happens from a camera frame to a spoken warning.”
- “Quiz me about Mobile Mode versus Raspberry Pi Mode.”
- “Give me a two-minute introduction and a five-minute demo script.”
- “Explain the model tensors, NMS, IoU, stability and risk estimation.”
- “Ask difficult viva questions and evaluate my answers honestly.”
- “Help me describe my actual engineering contribution without inventing fine-tuning.”

The later fine-tuning section contains a proposed experiment, not a report of completed training. A GPT reading this file must preserve that distinction.

## 2. Project in one paragraph

AI Blind Assistant is an Android assistive application for blind and visually impaired users. It uses a camera and lightweight object detectors to identify relevant objects, estimate their direction and relative visual priority, and provide short spoken alerts and bounded phone vibration. Mobile Mode processes the phone camera locally. Optional Raspberry Pi Mode processes a wearable camera on the Pi and sends compact authenticated messages to the phone over a private hotspot. The application also includes local document OCR, an accessible spoken reader, foreground local voice commands, settings and help. Optional Smart AI conversation can use a paired laptop or explicitly configured cloud providers. Core vision does not depend on these conversation services. The system supports awareness alongside established mobility aids; it does not guarantee safe navigation.

### A natural opening for your presentation

“Our project is AI Blind Assistant, an Android application designed to support blind and visually impaired users. It recognizes relevant objects locally and gives short feedback such as ‘Chair on the left.’ We support both a phone-camera mode and an optional Raspberry Pi wearable mode. We also provide document reading and local voice commands through an accessible interface. Our main contribution is integrating perception, feedback, voice interaction and local device communication into one practical assistive system.”

## 3. Problem, objectives and scope

The problem is not simply naming objects in a picture. A useful assistive interface also needs understandable feedback, accessible controls, predictable resource use, local operation, privacy, truthful errors and manageable announcement frequency.

The project aims to:

1. Identify supported generic object classes using local inference.
2. Express approximate horizontal direction in short language.
3. Prioritize selected detections without overwhelming the user.
4. Offer offline speech and finite phone haptic patterns.
5. Support phone-only operation and optional Pi camera placement.
6. Read printed text locally and provide accessible playback controls.
7. Allow bounded in-app voice commands without requiring a cloud LLM.
8. Keep sensitive information protected and disclose optional external processing.
9. Provide tested software and clearly record remaining physical limitations.

The system does not provide face identity recognition, calibrated distance in metres, autonomous navigation, GPS route guidance, comprehensive hazard coverage or guaranteed collision avoidance. Generic `person` detection identifies a class, not a person. Glass, stairs, drop-offs, small obstacles, objects outside the camera view and unusual environments can remain difficult or undetectable.

The final application uses native Flutter widgets. The preserved Stitch HTML and screenshots are design references, not a WebView implementation.

## 4. Current evidence: what is actually established

| Area | Evidence available as of this guide | Limit of that evidence |
|---|---|---|
| Android application | Version 1.4.18, Android version code 4058, installed on the owner's Pixel | Source pubspec uses an older base version; build flags supplied the delivered version |
| Vision AI listening | Owner confirms repeated commands and readiness cue work on Pixel | No guarantee for all accents, noise, speech or TalkBack combinations |
| Flutter software verification | Module 75 records 673 passing Flutter tests, including a real Python Pi simulator | These are recorded results, not reruns for this document or detector accuracy measurements |
| Android native unit verification | Module 75 records 25 passing app-native cases | Not every transitive plugin/instrumentation suite is established as passing |
| Android build | Module 75 records successful ARM64 debug and release builds | This documentation task creates no new APK |
| Pi deployment | Actual Pi 3B/OV5647 restored after fresh OS; NCNN warm-up and deployed source/model hashes verified | Does not prove custom household training or broad scene accuracy |
| Pi software checks | Module 76 records 38 passing Pi tests in 3.57 seconds, clean Ruff and shell syntax | Mostly software verification; real-world acceptance is separate |
| Pixel/Pi integration | Discovery, enrollment, authentication, settings sync, Running, Camera Active and Model Ready observed | Phone connection closes when the app is removed/backgrounded |
| Pixel wearable audio | Owner explicitly confirms test audio and actual object announcements both work | Limited functional acceptance, not a formal blind-user study |
| Pi runtime observation | More than 1,700 processed frames; zero service restarts in the observed session | One observation period, not an uptime guarantee |
| Pi performance | Selected samples: inference 516–575 ms; frame age 579–635 ms | Interval samples, not percentiles or a complete end-to-end benchmark |
| Pi power | Active undervoltage/throttling `0x50005`, about 600 MHz, powered from laptop USB | Performance is not accepted until stable power is measured |
| Fine-tuning | Current assets identify pretrained COCO/Open Images sources; custom training lineage is unverified | No supported custom dataset size, epoch count, accuracy gain or deployed custom checkpoint claim |
| Accessibility | Semantics and scaling have automated coverage; accessible controls exist | Comprehensive physical TalkBack and blind-user acceptance remain open |

At the final recorded Pi check there was no phone socket, after earlier successful foreground pairing/audio. Keep Wearable Mode open and reconnect with saved trust for phone alerts. The Pi detector continues independently when the phone disconnects.

## 5. Technology stack and the purpose of each component

| Technology | Where it runs | What it does |
|---|---|---|
| Flutter and Dart | Android phone | Native screens, state-driven UI, application orchestration and domain policies |
| Riverpod | Flutter application | State management and dependency injection |
| Centralized Flutter named routes | Flutter application | Consistent navigation and voice-to-screen actions |
| Kotlin and Android MethodChannels | Android native layer | LiteRT inference, speech recognition, permissions, local discovery, Keystore and device features |
| Flutter camera package / CameraX | Android phone | Camera preview, frame delivery and scanner capture |
| YOLOv8n | Phone and Pi | Lightweight pretrained object-detection architecture |
| LiteRT | Android native layer | Executes bundled `.tflite` detectors |
| NCNN | Raspberry Pi | Executes the exported Open Images detector locally |
| Python | Pi and optional laptop | Wearable service and assistant backend |
| Picamera2 / libcamera | Raspberry Pi | Camera capture through the Pi camera stack |
| NumPy and PyYAML | Raspberry Pi | Numerical processing and model/configuration metadata |
| WebSocket and JSON | Phone/Pi private LAN | Bidirectional commands, status, detections and feedback events |
| Android NSD, mDNS, Zeroconf, Avahi | Phone/Pi local network | Advertise and discover the wearable without a fixed IP |
| HMAC, nonces and sequence checks | Phone/Pi protocol | Authenticate messages and constrain replay |
| Android Keystore and AES-GCM | Android phone | Encrypt saved credentials using protected device keys |
| Android TTS / flutter_tts | Android phone | Speak alerts, reader content and assistant replies using installed offline voices |
| Vibration package / Android haptics | Android phone | Finite assistance vibration; native cue feedback for selected voice flows |
| Vosk | Android phone | Bundled offline English wake and command recognition |
| ML Kit Text Recognition | Android phone | Local printed-text OCR; current adapter selects Latin script |
| SharedPreferences | Android phone | Non-sensitive settings such as feedback and sensitivity |
| FastAPI, Uvicorn, Pydantic | Optional laptop | Authenticated HTTP assistant API, validation and serving |
| faster-whisper | Optional laptop | Explicit paired Speak-button transcription; default configured model is medium |
| Ollama | Optional laptop | Local conversational model serving; source default is `llama3.2:3b` |
| SQLite | Optional laptop | Explicit notes, reminders, schedules, preferences and bounded auth/audit records |
| Groq APIs | Optional cloud Smart AI | Explicit audio transcription with `whisper-large-v3` and selected answers with `openai/gpt-oss-20b` |
| Gemini APIs | Optional cloud text mode | Explicit text-only conversation, direct or through the laptop |
| AgentRouter adapter | Optional alternate cloud configuration | Legacy/explicit text-answer path; separate consent; client-access problem recorded |
| systemd and NetworkManager | Raspberry Pi OS | Service startup/recovery and hotspot profile management |
| Flutter test, JUnit, pytest, Ruff | Development | UI/domain/native/backend/Pi checks and static analysis |
| Git and living Markdown documentation | Development | Change tracking, evidence, decisions and handoff |

Important pinned/source details include LiteRT Android 2.1.5, Vosk Android 0.3.75, official NCNN 1.0.20260526, Python requirement 3.11 or newer, and a Dart SDK constraint of `^3.12.2`. Flutter dependency constraints include Riverpod `^3.3.2`, camera `^0.12.0+1`, flutter_tts `^4.2.5`, vibration `^3.2.0` and ML Kit text recognition `^0.16.0`. Constraints are not exact installed-version claims; lockfiles/build evidence identify resolved versions.

## 6. Architecture: three processing locations

```text
USER
  |
  +-- ANDROID PHONE
  |     Accessible Flutter interface + Riverpod controllers
  |     Phone camera -> LiteRT detectors -> filtering/risk -> speech/haptics
  |     Scanner camera -> local ML Kit OCR -> accessible reader -> speech
  |     Microphone -> local Vosk -> deterministic app controls
  |     Local settings + encrypted pairing/provider configuration
  |
  +-- OPTIONAL RASPBERRY PI, THROUGH PRIVATE HOTSPOT
  |     Pi camera -> Picamera2 -> NCNN detector -> bounded alert policy
  |     Authenticated compact events -> phone speech while connected
  |     Pi-local speech fallback after phone disconnect, if hardware works
  |
  +-- OPTIONAL CONVERSATION
        Paired laptop -> local Whisper/Ollama, optional text-only Gemini
        Or disclosed personal cloud Smart AI -> Groq speech/answers
        Reply text -> phone-local TTS
```

The phone is the interface and, in Mobile Mode, the perception computer. In Wearable Mode the Pi performs perception; the phone is not receiving video for inference. The laptop is optional conversation infrastructure and is not required between Pi and phone on the hotspot.

Optional LLM replies cannot issue device commands. Deterministic local routing authorizes bounded controls independently of generated conversation.

## 7. Code organization and why the layers matter

```text
mobile_app/
  lib/
    app/                controllers, providers, routing, voice orchestration
    domain/             entities, enums, policies and service contracts
    infrastructure/     camera, inference, networking, OCR, storage, speech
    features/           presentation grouped by feature
    core/               shared widgets, errors, accessibility and constants
  android/app/src/      native Kotlin handlers and native tests
  assets/models/        bundled phone detectors, labels and metadata
  test/                 Flutter unit, widget and integration-style checks

raspberry_pi/
  src/ai_blind_pi/      camera/detector adapters, service, protocol, feedback
  scripts/              deployment and network-startup helpers
  systemd/              service definitions
  model/                artifact contract and hashes, not duplicated binaries
  tests/                Pi unit/protocol/deployment checks

laptop_backend/
  src/ai_assistant/     FastAPI, auth, providers, transcription, tools, database
  tests/                unit and integration checks

docs/                   specification, decisions, evidence and known issues
deliverables/           APKs, presentation materials and this guide
```

Presentation renders state and invokes actions. Application controllers coordinate use cases. Domain code describes concepts and policies without importing camera or inference plugins. Infrastructure implements the contracts using real platform services. Riverpod supplies implementations and manages their ownership.

For example, a domain test can inject a fake inference service and test lifecycle behavior without a camera. A widget test can inject state and verify an accessible error label. A Pi simulator tests the actual cross-language protocol separately from physical hardware.

Centralized route definitions include Home, Modes, Mobile Assistance, Raspberry Pi, Settings, Help, About/Safety, permissions, Assistant/Connection/Settings and OCR Scanner. The implementation uses `MaterialApp.onGenerateRoute` and shared route constants.

The architecture has a known exception: scanner camera lifecycle code still exists in its screen widget. ISSUE-052 tracks extracting it into an injected service. Describe the intended separation and this exception rather than claiming perfect layering.

## 8. Screens and user-facing workflows

| Screen/feature | Main purpose |
|---|---|
| Startup | Introduce the application and privacy/safety context |
| Home | Show mode/state and offer primary actions |
| Mode selection | Choose phone camera or Pi wearable |
| Permissions | Explain/grant relevant camera or microphone access |
| Mobile Assistance | Start, pause, resume and stop phone detection; display boxes/status |
| Raspberry Pi / Wearable | Discover, pair, connect/start, inspect health and control the Pi |
| Settings | Feedback mode, sensitivity, cooldown, accessibility and local preferences |
| Scanner | Position a document and explicitly capture OCR |
| Reader | Speak recognized text and move between reading units |
| Vision AI | Foreground wake/command session and bounded local actions |
| Smart AI | Optional typed or explicit speech conversation; setup when unconfigured |
| Assistant connection/settings | Personal provider consent or local-laptop pairing/configuration |
| Help / About and Safety | Usage guidance, limitations and recovery |

“Native interface” means Flutter draws interactive application widgets; it does not mean every screen is written directly in Kotlin. Kotlin is used where Android-specific services are needed.

## 9. Exact object-detection models

| Path | Architecture and dataset | Runtime and precision | Output contract |
|---|---|---|---|
| Mobile general | YOLOv8n, COCO, 80 classes | LiteRT, FP32 | `[1,84,2100]` |
| Mobile household-oriented | YOLOv8n, Open Images V7, 601 labels | LiteRT, FP32, optional second interpreter | `[1,605,2100]` |
| Pi wearable | YOLOv8n, Open Images V7, 601 labels | NCNN, FP32 | Logical `[1,605,2100]`; observed NCNN matrix `[605,2100]` |

All three use 320×320 model input. The shared architecture name does not establish identical weights, label order, output size or training history.

The phone files are `yolov8n_float32.tflite` and `household_yolov8n_float32.tflite`, with separate labels and JSON metadata. The Pi uses `model.ncnn.param`, `model.ncnn.bin` and `metadata.yaml`. All files in a model set must remain consistent.

Mobile household metadata names the official `yolov8n-oiv7.pt` starting asset. Pi metadata identifies an Ultralytics Open Images V7-trained detector. Available records do not connect an owner-trained checkpoint to these exports. A friendly filename containing “household” is not proof of fine-tuning.

Ultralytics publishes Open Images V7 model information and pretrained YOLOv8 variants. That confirms upstream model availability; it does not establish this project's custom training. [Official Open Images V7 documentation](https://docs.ultralytics.com/datasets/detect/open-images-v7/)

### Why use a Nano detector?

The engineering goal is a lightweight detector suitable for evaluating constrained phone and Pi CPUs. Nano models trade capacity for resource use. Actual latency and accuracy still depend on the particular hardware, input, runtime, power and scene. Do not quote a vendor GPU benchmark as this Pi's measured performance.

### What do 84, 605 and 2,100 mean?

For the inspected exports, a candidate carries four box values and one score per class:

```text
84  = 4 box values + 80 COCO scores
605 = 4 box values + 601 Open Images scores
2100 = candidate locations in this exported head at the selected input size
```

The detector does not announce 2,100 objects. Filtering and suppression reduce candidate predictions to selected detections. The current parser does not add an extra objectness row or another softmax/sigmoid to these exported scores.

## 10. Mobile Mode: from Start to spoken feedback

1. The user explicitly starts assistance.
2. The controller checks camera permission and reports denial if necessary.
3. The camera adapter initializes a supported rear camera.
4. The inference adapter validates bundled metadata/assets and loads the native interpreter.
5. Native code inspects actual tensors and performs warm-up. It can load the optional household interpreter as well.
6. The image stream supplies YUV camera planes plus dimensions, strides, timestamp, orientation and lens direction.
7. Native code converts the frame to the model input and runs inference on a background executor.
8. Dart post-processing decodes boxes and class scores, filters confidence and performs per-class NMS.
9. If household output exists, its own labels/output dimensions are used; household policy and fusion combine results.
10. A spatial stability gate requires matching detections across two processed frames.
11. The risk policy estimates relative visual urgency and direction.
12. The alert policy selects useful bounded feedback, applies cooldowns and sends local TTS/haptic requests.
13. Pause, Stop, errors or lifecycle transitions cancel/release owned resources and stale operations.

The screen must not claim Detecting merely because Start was tapped. Permission, camera and model failures have distinct states. Session-generation checks prevent an old async startup from reviving a stopped session.

### Preprocessing in plain language

Camera preview data is not automatically the format a neural network expects. The code reads actual YUV row/pixel strides, converts to RGB, corrects rotation and mirroring, resizes while preserving aspect ratio, and pads unused space. This is letterboxing. The current pad color is RGB 114. Values are divided by 255, and the float32 input layout is NCHW `[1,3,320,320]`.

NCHW means batch, channels, height and width. RGB values are organized for the inspected model contract. Assuming NHWC without checking the artifact can produce incorrect input or runtime failure.

After inference, the code removes the letterbox padding mathematically and maps boxes back into normalized preview coordinates. Otherwise a correctly detected object could appear at the wrong overlay location or direction.

### Why frames are dropped while busy

The camera adapter limits delivery to roughly one frame every 200 ms, and busy guards prevent simultaneous inference jobs. Extra frames are discarded instead of making an ever-growing queue. This limits stale scene processing. A camera delivery limit is not a promise of detector FPS, especially when two phone models run.

### Confidence, IoU and NMS

Confidence is a model score used for filtering; it is not a calibrated probability that the real-world announcement is correct. Current sensitivity mapping is Low 0.60, Medium 0.45 and High 0.30. Higher sensitivity accepts more low-score candidates and may increase false alerts.

Intersection over Union (IoU) measures box overlap: intersection area divided by union area. Non-Maximum Suppression (NMS) keeps a stronger candidate and removes sufficiently overlapping weaker candidates of the same class. The ordinary per-class IoU threshold is 0.45. This is output processing, not learning new visual features.

## 11. Household processing and multi-model fusion

Mobile Mode can parse both the general and household outputs. The household engine has a list of domestic labels and categories such as furniture, appliances and kitchenware. Explicit Indoor mode adds a small 0.05 score adjustment for selected household labels, clamped to 1.0. The source does not establish that the “Auto” setting runs a learned indoor/outdoor scene classifier.

The fusion service combines output lists, groups overlapping identical or configured compatible labels, and computes confidence-weighted box coordinates. Its default overlap threshold is 0.50. It keeps the maximum contributing confidence, rather than a statistically calibrated combined probability.

Some configured compatibility pairs are semantically broad, such as chair/couch and cup/bottle. That can merge competing interpretations, so actual household evaluation matters. Do not describe fusion as a measured accuracy improvement without a comparison experiment.

When household results are absent the code can apply household processing to general results and retain the general path. An optional second model increases computation; it is not automatically faster or always more accurate.

These changes are domain-oriented post-processing and integration. They do not change the detector's trained weights and therefore do not constitute fine-tuning.

## 12. Relative risk, direction and alert pacing

For phone detections, normalized horizontal box center determines left, center-left, center, center-right or right. Spoken language collapses these into short directions such as “on the left,” “ahead” and “on the right.”

The Mobile risk heuristic uses:

```text
visual proximity score = 0.40 × box area
                       + 0.30 × box height
                       + 0.30 × box bottom position

relative importance = 0.45 × normalized size
                    + 0.35 × centrality
                    + 0.20 × configured class priority
```

Area, height and position are normalized image features. These formulas do not return metres. A large nearby-looking object may be important, but different object sizes, camera angle and occlusion can defeat the heuristic. “Very close” is a visual category, not sensor-calibrated depth.

The feedback orchestrator selects one high-priority useful alert per update, suppresses low risk and repeated signatures, uses a default three-second per-class cooldown and a global minimum interval of 1.2 seconds, and permits selected urgent risk upgrades to interrupt lower-priority speech. The saved cooldown is adjustable. These are Mobile-policy details; Pi has its own stability/rate policy and should not be assumed identical.

Examples are “Person ahead,” “Chair on the left” and “Bicycle on the right.” The intended benefit is concise awareness rather than reading every box aloud.

Phone haptics are finite: moderate risk uses one 100 ms pulse; high risk uses two 150 ms pulses with a gap; critical risk uses three 200 ms pulses with gaps. Low-risk alerts are suppressed. Stop and cleanup cancel output. A physical wearable vibration motor has not been specified/verified, so phone haptics do not establish Pi haptics.

## 13. Raspberry Pi wearable: components and processing

The verified hardware is a Raspberry Pi 3 Model B Rev 1.2 with an OV5647 camera, aarch64 Raspberry Pi OS and Python 3.13.5. The production Pi service executes the 601-label Open Images detector with NCNN. Model binaries are supplied separately and verified against a tracked hash manifest.

```text
OV5647 camera
  -> Picamera2 capture
  -> single-slot latest-frame buffer
  -> NCNN preprocessing/inference
  -> detection decoding and NMS
  -> stable priority/feedback policy
  -> compact authenticated phone event, or local speech fallback
```

The observed configuration uses 320×240 camera capture, a requested 8 capture FPS, 320×320 model input, four NCNN threads and frame stride 1. Capture size and network input size differ because preprocessing transforms the image. Requested capture FPS is not measured inference FPS.

Capture and inference have separate tasks. The buffer keeps the newest frame and discards obsolete buffered work. Inference/capture use off-event-loop work so the asynchronous service can remain responsive to networking. Bounded camera restart attempts and explicit error/status messages support recovery.

Pi feedback requires repeated class/direction observations and applies cooldown/rate limits. The configured normal announcement budget defaults to 12 per minute, with bounded urgent handling. When an authenticated phone is connected, phone TTS is preferred and Pi fallback speech is stopped to avoid simultaneous speakers. After disconnect, Pi `espeak-ng` is the configured fallback, but an actual usable speaker/audio route must exist. Its audibility was not separately accepted in the latest run.

The installed service is `ai-blind-assistant-pi.service`. Existing installation paths separate source/runtime/model, configuration and writable state. systemd enables boot startup; Avahi advertises discovery; a NetworkManager hook helps restore the service after Wi-Fi changes. Enabled startup is verified; a full cold-boot/outage matrix remains separate.

## 14. Phone hotspot, discovery and pairing

The Pixel provides a private Wi-Fi access point. Both laptop and Pi join it as clients. The phone application can communicate directly with the Pi; it does not need a laptop proxy. The Pi 3B setup uses a compatible 2.4 GHz hotspot.

DHCP assigns addresses, which may change after a restart. A hardcoded old address is unreliable. The Pi advertises `_aiba-wearable._tcp`; Android NSD discovers the current host/port. `rpi3-ml.local` or the discovered current private IPv4 address can be bounded fallbacks. The service uses automatic private-interface binding.

Wearable connection proceeds through discovery, selection, transport connection, enrollment or saved authentication, settings synchronization and acknowledged start/resume. The app should expose the actual step and truthful failures. Successful TCP alone does not prove pairing or running detection.

For an unclaimed Pi, explicitly enabled first-phone enrollment issues one random application credential and then closes enrollment while a credential remains active. This is trust on first use: perform it on the owner's isolated hotspot, because another client on an untrusted LAN could claim an unpaired Pi first. It is not a claim of certificate-verified device identity.

Android protects the saved credential using Keystore encryption. Later connections use authenticated protocol messages and saved trust. The Pi's Linux username/password is not the mobile-app pairing credential and is never embedded in the APK.

Nonce-bound HMAC authentication and signed sequence/replay controls help reject unauthorized or replayed messages. HMAC authenticates content; it does not encrypt it. The local WebSocket protocol is not TLS-confidential. Restrict it to the trusted private LAN and do not expose its port publicly.

The default wearable port is 8765. The optional laptop backend also uses 8765 on a different device, which is valid because an endpoint includes both host and port. Entering the Pi address into the laptop-assistant form would still target the wrong service.

## 15. Raspberry Pi power and the latest measured limitation

The Pi reported `0x50005`: current undervoltage and throttling plus historical flags. The observed ARM clock was approximately 600 MHz while powered by laptop USB. The detector still worked, but its observed inference intervals were around half a second. Those values should be presented with the power limitation attached.

The owner has an available 5 V / 3 A mobile charger. It had not been connected/tested in the recorded session. Its label alone cannot prove adequate voltage at the Pi; regulated output and cable losses matter. Raspberry Pi recommends a 2.5 A micro-USB supply for Pi 3. Cleanly shut down before changing the supply, then measure current flags and timing under load again. [Official Raspberry Pi power guidance](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#power-supply)

Do not hide the warning, increase clocks or lower detection safeguards to make a demonstration appear faster. Historical-only power bits can remain after the immediate fault disappears, so evaluate current bits separately.

If asked why detection is slow, a defensible answer is: “We observed a hardware power bottleneck: the Pi reported undervoltage and throttled to about 600 MHz. We recorded the timings under that condition. We need a stable supply and a repeat measurement before accepting performance.”

## 16. Local Vision AI voice commands

Vision AI is the phone-local foreground command system. It is different from open-ended Smart AI conversation. Its ordinary operation is:

```text
Microphone -> Android audio capture
  -> supported device audio processing
  -> bundled English Vosk model
  -> idle wake grammar
  -> “Hey Vision AI” / supported wake variant
  -> actual listening readiness and short cue
  -> contextual command grammar
  -> deterministic intent/authorization
  -> application action and spoken actual result
```

The user says the wake phrase, waits for Listening and the readiness cue, then gives one command. After feedback finishes and readiness returns, the next command can follow. The activated session remains available until an explicit exit/stop or lifecycle change. Ordinary listening pauses during spoken feedback; it is not unrestricted simultaneous speaking/listening.

Examples include opening Settings or Scanner, going Home, connecting to the Pi and starting or stopping approved in-app operations. The router uses screen context, so a short phrase such as “stop” can be interpreted conservatively rather than executing an unrelated action.

The native bridge serializes recognizer lifecycle/profile changes rather than replacing a recognizer beneath an active decoder thread. Latest repairs acknowledge actual resume, recover selected echo/empty-callback paths, share bounded recovery, cancel stale starts and allow a one-second command trailing-silence window. A short tone/vibration follows actual readiness; an accessible Restart voice listening control supports recovery.

Missing-word markers and negation must not become positive controls. Fuzzy/polite alias handling is bounded; an unclear utterance should ask for a retry instead of guessing a dangerous action. A local language model is not needed to decide “open settings.”

Device acoustic echo cancellation, noise suppression and automatic gain control are requested only where supported. Their availability and effectiveness vary. Reader playback has additional echo guards and conservative interruption handling; that does not establish perfect barge-in in every acoustic environment.

The bundled wake/command path uses Vosk independently of laptop Whisper. Changing the laptop model does not improve the bundled Vosk vocabulary. Manual speech may use a dedicated Android on-device recognizer when available, with bundled Vosk fallback; do not assume Android's default online recognition service is required.

Foreground/unlocked operation is the supported boundary. Do not promise always-on lock-screen listening or control over arbitrary Android applications. Microphone audio for the local wake/command path is transient and is not uploaded or retained.

## 17. Document Scanner and accessible reader

Object detection and OCR solve different tasks. YOLO predicts object classes/boxes. ML Kit extracts printed characters. The current OCR adapter explicitly selects Latin-script recognition; do not claim verified Urdu document OCR because the conversational assistant can speak Urdu.

The scanner workflow is:

1. Open Scanner and grant camera permission.
2. Use coarse lighting/alignment guidance from preview luminance and contrast.
3. Explicitly tap Scan or say the supported scan command.
4. Capture a temporary local still image.
5. Run local ML Kit text recognition and collect recognized lines.
6. Delete the temporary image during normal/error/cancellation cleanup.
7. Normalize text into readable units and start or control local playback.

Framing guidance is heuristic. It does not prove every document edge is found, every word is sharp or the content is correct. Exact capture resolution depends on the camera path/device; no universal 4K or neural-accelerator claim is established here.

The reader joins soft line wraps and protects common abbreviations/decimals while splitting text into reading units. These are rule-based text-processing operations, not a separately trained NLP model. A reading “line” may be a reconstructed sentence and differ from a printed line.

Controls include play/pause/resume/stop, repeat, previous/next, first/last/numbered unit, spelling and reading profiles. The current/recent spoken text is checked to reduce self-triggering when the page contains words resembling commands. Supported multiword reader controls have guarded recognition during playback, but real overlapping speech/TalkBack remains a physical test.

“Scan again” or “restart scanner” clears the old page and returns to positioning. The user has unlimited time to align the next page; an explicit Scan captures it. “Restart reading” instead returns to the existing text's first reading unit.

Ask AI copies recognized text into an editable draft. The user must explicitly send it to the configured conversation destination. OCR itself is local, but text sent in a conversation follows that mode's disclosure. Do not use unverified OCR output as the sole basis for medication or other high-stakes decisions.

## 18. Smart AI: three distinct optional paths

| Path | Speech-to-text | Answer generation | Network requirement |
|---|---|---|---|
| Paired laptop | Explicit Speak-button clip sent to local faster-whisper medium | Local Ollama; optional Gemini text reasoning with Ollama fallback | Private LAN; internet only for enabled cloud reasoning |
| Personal direct Gemini text mode | Typed or supported phone-local transcription; no raw audio sent to Gemini | Personal Gemini configuration | Internet for conversation |
| Personal cloud Smart AI | Explicit bounded foreground audio sent to Groq `whisper-large-v3` | Selected Groq `openai/gpt-oss-20b`; explicit legacy AgentRouter alternative | Internet and personal provider setup |

These paths are not one interchangeable “AI model.” Speech recognition, text generation and object detection are separate components.

### Paired-laptop conversation

The phone authenticates to a FastAPI service on the trusted private LAN. Typed input skips recording. After disclosed owner-approved Speak-button capture, a temporary clip may go to the paired laptop for local Whisper transcription. The default source configuration uses Whisper medium, deterministic decoding, configured language handling and local cached models. Ambiguous/repetitive speech is rejected before command or question routing.

The backend uses local Ollama by default, with source model setting `llama3.2:3b`. If a personal Gemini key is configured, text reasoning can prefer Gemini and fall back to Ollama on failure. The source default Gemini model string is `gemini-3.6-flash`; a configurable string is not proof of live provider availability. This guide does not inspect private environment values or promise live quotas.

Temporary speech clips are deleted on phone/backend success, cancellation and failure paths. Conversation persistence is disabled by default. Explicit notes/reminders/schedules/preferences are stored locally in SQLite; generated conversation is not silently turned into a stored personal profile.

### Personal cloud Smart AI

This newer, narrow exception allows only explicit foreground Smart AI capture after provider-specific disclosure, personal key entry and consent. The sequence is recorded audio, transcription, text answer and phone-local TTS. It is file-based turn-taking, not full-duplex live streaming.

Native recording uses 16 kHz mono AAC/M4A with 30-second and 4 MB limits. Audio goes to Groq's transcription endpoint; conversation text/history goes to the selected answer provider. Groq mode uses `whisper-large-v3` and `openai/gpt-oss-20b`. It never silently calls AgentRouter. The older `deepseek-v4-flash` AgentRouter adapter remains an explicit alternative with a recorded client-access issue.

Typed questions skip transcription. Network operations have time/response bounds and cancellation; stale results cannot revive an exited screen. No provider response is executed as a command. There is no unlimited/free-access or guaranteed-latency claim.

The large circle supports deliberate hold, readiness cue, speech and release, with labelled accessible alternatives. English/Urdu selection can constrain transcription and reply language. Auto language identification can mishear very short utterances. Urdu output needs an installed offline Android Urdu voice; English/Urdu conversation support is not evidence of multilingual Vosk commands or Urdu OCR.

Phone clips are deleted after transcription and on cancellation/failure, with scoped cleanup of orphan temporary clips on a later capture. Deleting the phone file does not delete a cloud provider's copy or guarantee the provider's retention policy. Keys and provider selection are encrypted separately in Android Keystore-backed storage.

On a fresh phone the Smart AI circle/setup view remains visible, but question capture/submission is disabled until personal configuration and consent. Local app commands and cue/help controls remain available. The owner's existing configuration/consent must not be assumed to transfer to a new phone.

### Local commands during Smart AI

Foreground idle/paused local controls support bounded actions such as going Home/Back and exact goodbye handling. Explicit Smart AI recording owns the microphone during capture, then releases it for local controls. That handoff does not authorize cloud wake listening or automatic uploads of ordinary conversation around the phone.

## 19. Accessibility and interaction design

Accessibility includes meaningful page titles, named controls, logical focus order, semantic headings, selected/disabled states, scalable text, high contrast, reduced motion, speech and optional finite haptics. Status is expressed with text/semantics instead of color alone. Touch, labelled buttons and voice alternatives help when one interaction method fails.

Native Flutter semantics exposes application structure to TalkBack. A passing widget semantics test verifies the constructed accessibility tree under test conditions; it does not establish how a blind user experiences the complete application.

Remaining review includes physical TalkBack navigation, speech conflicts, large-text/orientation behavior, microphone permissions, actual cue sensation, audio routing and comprehension. A known Scanner narrow-width header problem is recorded. No formal participant study, task-completion result or accessibility-certification claim is available.

The design intentionally avoids time-limited document alignment. Readiness cues follow actual listening/capture startup so the user has a meaningful signal for when to speak.

## 20. Storage, privacy and security

| Data | Handling and boundary |
|---|---|
| Object-detection frames | Transient processing on the capture device; no frame streaming/upload or retained scene history |
| Scanner still image | Temporary local OCR input; cleanup after processing/cancel/error |
| Recognized document text | Used locally for reading; explicitly reviewed/sent draft may reach selected assistant destination |
| Local wake/command audio | Transient phone recognition; no cloud upload or recording retention |
| Paired Speak-button audio | Disclosed temporary private-laptop processing and cleanup on both sides |
| Opted-in cloud Smart AI audio | Bounded temporary clip to Groq only; local cleanup does not control provider copies |
| General settings | Local SharedPreferences |
| Pi/assistant credentials and personal provider keys | Separate encrypted Keystore-backed phone entries |
| Pi state | Protected credential verifier/settings on the Pi |
| Laptop personal utilities | Explicit local SQLite records, with validation/confirmation for relevant operations |
| Diagnostic information | Bounded technical states/aggregate timing; no raw frames, credentials or personal recordings |

No Firebase, advertising analytics, remote crash reporting, accounts or face identity profiles are introduced. Ordinary core vision has no cloud inference. The phrase “the whole app is 100% offline” is too broad because optional cloud Smart AI exists; say “core vision, OCR and bounded app commands run locally.”

Android backup is disabled for protected application data. Keystore encryption protects stored credentials but does not make a device immune to every compromise. HMAC protection on the Pi protocol does not provide encrypted transport. The local laptop HTTP transport also requires a trusted private LAN; do not expose either service publicly.

The application does not store hotspot passwords. Android/Raspberry Pi OS owns Wi-Fi configuration. SSH is an administration/deployment tool, separate from app pairing; the Android app does not log in to Linux using the owner's password.

## 21. What your actual contribution can include

The deployed pretrained neural network is one component of a much larger engineering project. A defensible contribution statement is:

“We integrated pretrained lightweight detectors into an accessible Android assistive application. Our implementation handles camera preprocessing, native inference, tensor decoding, temporal stability, relative risk, bounded audio/haptics, local voice commands, document reading and authenticated Pi communication. We also implemented lifecycle cleanup, privacy boundaries, recovery states and automated verification. We describe custom fine-tuning as future work unless reproducible training and deployment evidence is supplied.”

Substantial work exists in the interface, service boundaries, timing, state machines, feedback policy, pairing, speech ownership and verification. Using pretrained weights is normal for a systems project; it does not require inventing an original architecture or custom training result.

This guide does not establish who personally authored each component or how much external/AI assistance was used. Describe your own role, team contributions and development assistance according to what actually happened and your institution's rules. Being able to explain a component is different from having created its upstream model.

## 22. Fine-tuning: how to answer accurately

### The current claim boundary

Earlier presentation material repeated an owner-reported household fine-tuning claim. Available repository evidence does not establish the dataset, actual training run, checkpoint, held-out metrics or export lineage for that claim. The current request explicitly treats fine-tuning as something that may not have occurred. Therefore this guide does not repeat it as completed work.

Do not fabricate a dataset count, collection story, annotation tool, GPU, epochs, training curve, checkpoint, confusion matrix or improvement percentage. A made-up explanation creates follow-up questions that require more invented evidence. The professional answer is specific about what you actually integrated and measured.

### Words that mean different things

| Term | Actual meaning | Does it establish fine-tuning? |
|---|---|---|
| Pretrained model | Weights learned previously by an upstream training process | No new training by this project |
| Inference | Running existing weights on an input | No |
| Export/conversion | Turning a checkpoint into a runtime artifact such as LiteRT or NCNN | No |
| Threshold tuning | Changing confidence, overlap or alert rules | No |
| Household label filtering | Choosing/reprioritizing existing predicted classes | No |
| Score adjustment | Applying an explicit heuristic after inference | No |
| Multi-model fusion | Combining outputs from existing models | No |
| Testing household images | Observing predictions on local scenes | No |
| Quantization | Changing numerical representation with a defined calibration/verification process | A separate optimization; not automatically fine-tuning |
| Fine-tuning | Updating pretrained network weights through training on a specified dataset/objective | Yes, if the run actually occurred and can be evidenced |

### Presentation-ready answers

**If asked “Did you fine-tune the model?”**

“The deployed version uses pretrained YOLOv8n models. Our completed work is integration and application-level adaptation for assistive feedback. We have household-oriented detection and post-processing, but we are not claiming a custom fine-tuned checkpoint without its training and evaluation records.”

**If asked “Why did an older slide mention fine-tuning?”**

“That wording overstated the verified result. We corrected the distinction between pretrained model integration, household post-processing and actual weight training. The deployed artifacts and current evaluation claims are described separately.”

**If asked “What improvement did household adaptation produce?”**

“We added broader Open Images labels and household-oriented processing. We have not completed a controlled held-out comparison, so we cannot state an accuracy improvement percentage.”

**If asked “Why should this count as a project without training from scratch?”**

“The project evaluates and integrates perception into an accessible working system with two hardware modes, local interaction, feedback policies, privacy and recovery. Training a detector from scratch is a different research objective.”

These answers acknowledge the limits while explaining completed engineering work. Do not present a proposed training experiment in past tense.

## 23. A genuine household fine-tuning plan — proposed, not executed

This is a workflow for future authorized research. No training, image collection, model replacement or download was executed while creating this guide. Existing project scope defers custom training until it is approved and evaluated.

### Step 1: Define the claim and class set

Decide whether the experiment targets better recognition of existing household classes or introduces new classes. Define exact labels and intended scene conditions. A small household-only label set changes the detector head/metadata and may reduce coverage of people or outdoor hazards. Preserve the current validated baseline for comparison and rollback.

### Step 2: Obtain appropriate data

Use consented/licensed research images with representative furniture, containers and appliances across rooms, lighting, viewpoints, scale, clutter and occlusion. Include difficult negatives and empty scenes. Record provenance and permissions. Any future collection involving this app or private homes needs its own approved privacy workflow; this project's live camera frames are not an authorized training dataset to retain.

### Step 3: Annotate and review

Use a consistent class dictionary and correct bounding boxes. Have an annotation review process and track ambiguous cases. For YOLO-style detection labels a record commonly contains a class index and normalized box center/width/height; validate label ranges and match every class index to its exact name. Do not pretend that unlabeled photos alone are a supervised detection dataset.

### Step 4: Split without leakage

Separate training, validation and final test sets by scene/room/object instance or recording session where appropriate. Near-identical frames from a burst should not fall into both training and testing. Declare the split and its rationale. Keep the final test set out of tuning decisions. A classroom demo object selected after many retries is not a held-out benchmark.

### Step 5: Evaluate the pretrained baseline first

Run the chosen pretrained checkpoint on the held-out evaluation setup using the intended label mapping. Record per-class precision/recall/AP, false alarms, missed instances and difficult examples. This establishes what improvement would mean. Make preprocessing, thresholds and input size explicit.

### Step 6: Train a reproducible experiment

Start from an identified pretrained checkpoint and record its hash. Keep the dataset/configuration, framework version, seed, hardware, input size, optimizer settings, augmentation, actual epochs and stopping rule. Use the validation set for decisions. Do not invent optimal hyperparameters or a universal dataset-size requirement in advance. Ultralytics provides the upstream training interface; a local run and saved artifacts must establish the project's actual experiment. [Official training documentation](https://docs.ultralytics.com/modes/train/)

### Step 7: Evaluate honestly

Compare baseline and trained checkpoints on the same final held-out set with matched conditions. Report class-level results and failure cases, not only one favorable average. Check whether household gains cost general-object recall. Measure variability where the study design permits it. Validation tooling reports metrics such as precision, recall, mAP50 and mAP50–95; tool output is not a guarantee of useful assistive performance. [Official validation documentation](https://docs.ultralytics.com/modes/val/)

### Step 8: Export and validate the actual trained checkpoint

Export that exact checkpoint to the required LiteRT/NCNN format, generate labels/metadata and verify real tensor shapes. A changed class count changes output dimensions. Compare exported predictions with the source checkpoint; export compatibility can differ by framework/runtime version. Do not rename an old baseline model file and call it the trained export.

### Step 9: Establish deployment lineage

Keep an auditable chain: source checkpoint hash, dataset/config revision, training run, selected output checkpoint hash, export configuration, exported-file hashes, packaged APK or Pi-install hashes and runtime validation. Hashes prove artifact identity and linkage; a hash alone does not prove model quality or that training happened.

### Step 10: Evaluate the assistive system

Measure target-device latency, frame age, memory, power/thermal behavior, false spoken alerts, missed relevant detections and user comprehension. Review labels, risk policy, fallback and regression tests before replacing any model. Use stationary controlled tests and appropriate supervision; no unsupported mobility-safety claim follows from higher mAP.

### Evidence checklist before saying “we fine-tuned”

- Real dataset provenance, class map, annotations and leakage-aware splits.
- Actual training script/configuration and environment versions.
- Actual training log, selected checkpoint and training parameters.
- Baseline and post-training held-out evaluation using a documented protocol.
- Real class-level results, failure examples and resource measurements.
- Source-to-export-to-installed-artifact lineage with hashes.
- Clear limits and a statement of whether the trained model is deployed or only experimental.

## 24. Evaluation: metrics you should understand

An object detector's useful evaluation needs annotated scenes and a declared matching rule. Define true positives, false positives and false negatives at the chosen class/IoU rule, then report:

```text
precision = true positives / (true positives + false positives)
recall    = true positives / (true positives + false negatives)
IoU       = overlap area / union area
```

Average Precision summarizes the precision-recall relationship for a class. Mean AP averages the defined class AP values; mAP50 uses IoU 0.50, while mAP50–95 averages the standard range of overlap thresholds. State the exact evaluator/settings and class inclusion rather than mixing benchmarks. A detector score threshold of 0.45 does not mean 45% measured accuracy.

This project also needs system metrics: capture-to-alert latency, inference latency, frame age, repeated-alert rate, false announcements, missed relevant events, reconnection time, memory, battery/temperature and accessible task success. A model with higher offline AP can still be frustrating if announcements are late or repetitive.

The current test counts are software checks. The historical PyTorch-versus-LiteRT reference-image comparison is export parity/sanity evidence. Owner-confirmed bottle/chair speech is a functional test. Neither establishes dataset-wide detection accuracy or a user-study outcome.

For the Pi, 516–575 ms inference samples were recorded under undervoltage. Do not present their inverse as measured sustained FPS or report them as percentiles. End-to-end delay also includes capture, frame age, stability, event transport, speech ownership and TTS startup.

No verified project-specific accuracy percentage, fine-tuning gain, participant count, task-success rate or mean latency distribution is supplied in this guide.

## 25. Testing strategy and dated results

| Test layer | What it can establish | Example in this project |
|---|---|---|
| Domain/unit | Rules behave on controlled inputs | NMS, direction/risk, cooldown, intents, reader segmentation |
| Widget/accessibility | UI renders/reacts and exposes semantics | Settings, disabled/selected actions, readable errors, scaling |
| Native Android app unit | Kotlin components behave on test inputs | Wake grammar, readiness cue lifecycle and capture-related helpers |
| Backend unit/integration | API/auth/providers/tools/transcription cleanup obey contracts | Invalid auth, limits, typed failures and mocked provider fallback |
| Cross-stack simulator | Real message encoding/auth/session behavior across Dart/Python | Wearable simulator end-to-end checks |
| Build/package | Source compiles/packages and artifact properties match | ARM64 debug/release, signing, 16 KiB alignment, non-debuggable flags |
| Physical functional | Actual devices perform the tested operation | Pixel command/cue and wearable object speech acceptance |
| Formal field/usability | Defined tasks work for representative users/scenes | Remains open; no participant result invented |

Recorded Module 75 results on 21 October 2026 are 673 Flutter tests, 25 native app tests, clean static analysis, formatting and successful ARM64 debug/release builds. The release-mode APK was installed in place on Pixel with matching installed bytes and retained settings/permissions. That device update reused the predecessor's development signer for compatibility; do not claim a store-ready production signing/release process.

Recorded Module 76 results on 22 October 2026 are 38 Pi tests in 3.57 seconds, clean Ruff/shell syntax, actual model hashes, 19/19 installed Python module hashes, real NCNN warm-up, camera activity and physical pairing/audio acceptance. The prior backend speech report records 128 backend passes on 16 October; it is dated historical evidence, not a new whole-backend run for this guide.

The documentation task does not rerun these suites or create new build results. It checks document structure/export, evidence consistency, links, whitespace and preservation of the source baseline instead.

## 26. Setup and operation overview

### Phone-only core use

Install the authorized APK, grant camera permission for detection/scanning, configure an installed offline TTS voice, choose feedback/sensitivity and explicitly start Mobile Mode. Microphone permission is relevant to voice features, not required merely to run object detection. Verify an actual audible alert and desired haptics before relying on feedback.

### Pi wearable use

Use the existing installed service/model and compatible private hotspot. Keep the Pi safely powered and the camera connected. Join the Pi to the hotspot, enable the hotspot, open Wearable Mode and use Connect & Start Detection. First use enrolls; later sessions reuse protected trust. Check Camera Active, Model Ready, Assistance Running and power status. Test phone audio. Keep the app visible for phone announcements.

Reflashing Pi OS removes installed service/runtime/models and changes SSH host identity. It is not a routine connectivity repair. Restoring the actual Pi was necessary after the owner's reflash; normal operation should not repeat that installation.

### Optional laptop use

Prepare local Whisper and Ollama models on the laptop before offline use, start the FastAPI backend on the trusted LAN and perform its separate application pairing. A preparation-time download is different from a runtime cloud dependency. Preserve protected environment/configuration and never put keys/passwords into source or presentation screenshots.

### Optional personal Smart AI

Select the desired provider in the app, enter your personal key through the obscured setup form and review its specific audio/text disclosure. Configure installed English/Urdu offline voices as needed. Cloud conversation requires internet, provider access and quota; local controls and core vision remain separate.

### Developer command examples

These are reference commands, not commands executed to create this guide. They assume dependencies, local runtimes and SDKs have already been prepared. Do not blindly replace the demo phone APK/signature just to rehearse commands.

```sh
# From mobile_app: software analysis and tests
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub

# Example Android debug build; this does not install it
flutter --no-version-check build apk --debug --target-platform android-arm64

# From repository root: Pi tests and existing local Ruff tool
raspberry_pi/.venv/bin/python -m pytest -o addopts='' raspberry_pi/tests -q
laptop_backend/.venv/bin/ruff check raspberry_pi/src raspberry_pi/tests

# On the Pi: read-only operational checks
systemctl status ai-blind-assistant-pi.service
vcgencmd get_throttled
vcgencmd measure_clock arm
```

Full Flutter simulator cases may need the repository's `AIBA_PI_PYTHON` configuration. Installing over a release-mode demo build requires compatible signing; `pubspec.yaml` alone does not reproduce the separately supplied version/build overrides. Follow the dated build reports for exact artifact reproduction.

## 27. Troubleshooting without overclaiming a fix

| Symptom | What to inspect | Interpretation/action |
|---|---|---|
| Pi not discovered | Power, same hotspot, 2.4 GHz compatibility, service/Avahi, current private address | Discovery failure is not automatically a model failure |
| TCP opens but Start fails | Authentication, settings sync, model/camera state, actual acknowledgement | A socket alone is insufficient evidence of running assistance |
| Phone wearable alerts stop | App foreground, saved connection, audio setting, media volume/TTS route | Pi may still detect independently; reconnect with saved trust |
| Pi is slow | Current undervoltage/throttle bits, clock, CPU/thermal state and measured timing | Correct power before accepting performance; do not infer speed from a passing unit test |
| Same object is not repeated | Stability, cooldown, direction/risk changes and rate budget | Deliberate suppression may explain silence; check actual state |
| Wrong/missing object | Label coverage, lighting, blur, scale, angle, confidence, fusion | Recognizable class names do not guarantee every instance is detected |
| Voice hears wake but misses command | Wait for readiness cue, speak one command, avoid speaking over feedback, restart listening if error | Local Vosk limitations remain; use the named button when needed |
| Smart AI says setup required | Personal key/provider consent on this phone | Saved credentials do not automatically migrate between phones |
| Smart AI speech fails | Capture permission, foreground state, selected language, provider/network/quota and installed TTS voice | Transcription, answer generation and speech output are separate failure stages |
| Scanner reads old page | Return to framing with Scan Again, then explicitly Scan | Rescan intentionally does not auto-capture |
| OCR has mistakes | Lighting, focus, angle, print size and supported script | Review text; do not invent an accuracy guarantee |
| SSH key changed after reflash | Confirm the OS/identity change and verify trust appropriately | Do not globally disable host-key checks |

The latest observed Android exit after app removal was user-requested removal from recent tasks, with no matching crash diagnostic. That particular event should not be reported as an unexplained crash. It does not prove the app can never crash.

## 28. Two-minute explanation you can practice

“AI Blind Assistant is an Android assistive system for blind and visually impaired users. It identifies supported objects through a camera and gives concise direction-based spoken feedback, with optional bounded vibration in Mobile Mode.

“We built the application in Flutter and Dart, use Riverpod for state management, and use Kotlin bridges for native Android capabilities. Our lightweight detectors are pretrained YOLOv8 Nano models. Mobile Mode uses LiteRT with a general COCO detector and an optional Open Images household-oriented detector. The wearable Pi uses the Open Images model through NCNN.

“Frames are preprocessed, inferred locally, filtered and stabilized. We estimate visual priority from properties such as box size, centrality and class. This estimates relative risk; it is not exact distance. Cooldowns prevent repeated announcements.

“The Pi and phone communicate over a private hotspot using authenticated compact messages. Camera frames stay on the Pi. The app also provides on-device OCR, an accessible reader and local Vosk commands. Optional Smart AI conversation is separate and discloses any external processing.

“We verified software with automated tests and Android builds, and tested Pixel pairing and spoken object announcements. Our remaining limitations include Pi power throttling, broader accuracy/accessibility evaluation and incomplete real-world safety validation. We present the system as an additional awareness aid, alongside established mobility support.”

## 29. Five-minute demonstration plan

1. **Introduce the purpose and boundary, about 30 seconds.** Explain awareness support and the distinction between local vision and optional conversation.
2. **Show accessible controls and local settings, about 30 seconds.** Use named buttons, feedback selection and sensitivity. Mention TalkBack support without inventing a completed user study.
3. **Demonstrate a stable Mobile object scene, about 45 seconds.** Show a recognizable supported object in good lighting. Explain direction, stability and cooldown rather than promising every object is announced immediately.
4. **Show wearable status and one real alert, about 60 seconds.** Keep Pixel Wearable visible, confirm Running/Camera Active/Model Ready and present a stationary object. Explain that the Pi computes locally and only compact messages cross the hotspot. Disclose power warning if still present.
5. **Scan a simple large-print document, about 60 seconds.** Align, explicitly Scan, read, pause and move through a reading unit. Keep a named touch alternative ready.
6. **Use a local voice command, about 30 seconds.** Wake, wait for readiness, say “open settings,” wait for response, then go Home. Do not speak over the feedback.
7. **Explain optional Smart AI and evaluation, about 45 seconds.** It can be described without sending a paid/private question. Show configured local/cloud distinction and close with actual evidence/limitations.

Timing is a rehearsal target, not a measured app latency claim. Use a stationary, controlled setup. Do not demonstrate road crossing, unsupervised navigation or intentionally unsafe obstacles. If a feature fails, state the visible failure and use the named control; do not claim a simulated result is live inference.

## 30. Viva questions and concise defensible answers

**1. What is the main purpose?**

To support environmental awareness and access to printed text through an accessible Android interface, local perception and understandable feedback.

**2. Is this navigation or object detection?**

It is primarily object awareness and document reading. It does not generate a safe walking route or guarantee collision avoidance.

**3. Why Flutter?**

It supports a native widget interface, shared application/domain code, semantics and testable UI. Android-specific performance and security functions are implemented through Kotlin bridges.

**4. Why Riverpod?**

It provides one mechanism for state and dependency injection, allowing explicit ownership and controlled service substitution in tests.

**5. Why use Kotlin as well as Dart?**

Native APIs are needed for LiteRT execution, Android recognition, Keystore, permissions and local discovery. MethodChannels connect these services to the Flutter application.

**6. Which exact detector runs on the Pi?**

YOLOv8n trained on Open Images V7, exported for NCNN with 320×320 input and 601 label entries.

**7. Does the phone use the same artifact?**

It uses LiteRT files: an 80-class COCO model and an optional 601-class Open Images household-oriented model. Runtime files, label maps and outputs differ from the Pi export.

**8. Did you invent YOLO?**

No. YOLO and its pretrained weights are upstream technology. The project's contribution is the assistive application, integration, interaction policies, hardware communication and verification actually implemented.

**9. Did you fine-tune it?**

The current verified deployment uses pretrained models; custom training is not claimed without its reproducible run and deployment evidence. Household post-processing is implemented separately.

**10. What is NMS?**

It suppresses weaker overlapping same-class candidate boxes so one object does not appear as many duplicate detections.

**11. What is IoU?**

The ratio of the overlapping area of two boxes to their combined union area. It is used for overlap/matching decisions.

**12. Why is the model input NCHW?**

That is the inspected export's actual input contract. Preprocessing must match the artifact's layout, color, normalization and dimensions.

**13. Why not announce every detection?**

Continuous announcements can overwhelm the user. Stability, priority, cooldown and rate limits select useful feedback and reduce repetition.

**14. How is distance measured?**

There is no calibrated metric distance measurement. Image size/position contribute to a relative visual proximity and risk heuristic.

**15. How do you detect a familiar person?**

The project does not identify people. It detects the generic person class and stores no face identity database.

**16. Why use a Pi wearable?**

It allows external camera placement while keeping perception local. It adds power, camera, network and mounting constraints that need physical validation.

**17. Does the Pi stream video to the phone?**

No. It performs inference locally and sends compact authenticated status/detection/feedback messages.

**18. Is the laptop required for wearable detection?**

No. On the verified private hotspot, Pixel and Pi communicate directly. The laptop is optional conversation/admin infrastructure.

**19. What happens if the phone disconnects?**

Phone speech stops receiving Pi events. The Pi detector can continue and use configured Pi-local speech fallback when a working audio route exists; that speaker requires its own acceptance check.

**20. Is HMAC encryption?**

No. It authenticates message integrity/origin under a secret. This version's local transport does not provide TLS confidentiality.

**21. Why does the app not use the Pi's SSH password?**

Linux administration and app pairing serve different purposes. The app uses a random revocable application credential protected by Android Keystore.

**22. Does changing the hotspot IP break pairing?**

Pairing is associated with saved device identity/credential. Discovery can update the endpoint; the complete DHCP/outage matrix still needs broader testing.

**23. Which recognizer hears “Hey Vision AI”?**

Bundled phone-local English Vosk. Laptop Whisper and optional Groq transcription are separate explicit speech paths.

**24. Why not route all controls through an LLM?**

Bounded deterministic routing is predictable, offline and easier to authorize/test. Generated conversation cannot execute arbitrary controls.

**25. Can it listen while the phone is locked?**

Always-on lock-screen/background operation is not the supported claim. The demonstrated interaction is foreground and unlocked.

**26. Is OCR another YOLO model?**

No. The app uses local ML Kit Latin-script text recognition, then rule-based text segmentation and local TTS playback.

**27. Does Urdu Smart AI mean Urdu OCR works?**

No. Conversation language, local command vocabulary and document recognition scripts are separate capabilities. Current OCR selects Latin script.

**28. Is everything offline?**

Core vision, local OCR and app commands are local. Laptop Ollama can also run locally after preparation. Explicit Gemini/Groq/AgentRouter modes require internet and consent.

**29. What does a passing test suite prove?**

Specified checks passed in their recorded environment. It does not prove detector accuracy, audibility in every setting, complete accessibility or safe navigation.

**30. What is your achieved accuracy?**

No verified project-specific accuracy percentage is available. We report actual software and functional-device evidence and need an annotated held-out evaluation for accuracy claims.

**31. What is the Pi's current bottleneck?**

The observed system had active undervoltage/throttling near 600 MHz on laptop USB. We need stable power and repeat measurement before accepting sustained performance.

**32. What is your future work?**

Correct power, evaluate representative scenes and accessibility, complete recovery/thermal/battery matrices, and investigate genuinely documented fine-tuning/optimization if authorized. New distance sensing would need its own design and validation.

## 31. Common statements to correct before presenting

| Avoid claiming | Say instead |
|---|---|
| “We trained YOLO ourselves” | “We integrated pretrained YOLOv8n detectors,” unless actual training evidence is available |
| “We fine-tuned because we tested household photos” | “We tested local scenes; training would require weight updates and an evidenced experiment” |
| “The household threshold improves accuracy by X%” | “It changes output behavior; improvement needs a controlled evaluation” |
| “The Pi recognizes every household object” | “Its label vocabulary has 601 entries; actual detection depends on conditions” |
| “84 is the number of classes” | “The COCO head has 4 box values plus 80 class scores” |
| “8 camera FPS means 8 inference FPS” | “Capture configuration and measured inference throughput are separate” |
| “The app measures exact distance” | “It estimates relative visual priority/proximity” |
| “HMAC encrypts the network” | “HMAC authenticates messages; trusted LAN remains necessary” |
| “The entire app never accesses a cloud” | “Core vision is local; explicitly configured Smart AI can use disclosed cloud services” |
| “We passed 673 accuracy tests” | “673 Flutter software tests passed in the dated run” |
| “The demo proves blind users can navigate safely” | “The demo shows selected functions; formal user/safety validation is incomplete” |
| “All languages work because Urdu speech works” | “Language support differs among Vosk commands, OCR, transcription and installed TTS” |
| “The APK is a store-ready production release” | “A verified prototype release-mode artifact is installed; production distribution work remains” |

## 32. Limitations and next work, in priority order

1. Correct Pi power and repeat measured latency/frame-age/thermal tests.
2. Complete representative household and general-object evaluation with defined labels and ground truth.
3. Review physical TalkBack, large text, audio routing, haptics and blind-user task experience.
4. Complete hotspot restart, DHCP change, camera fault, reboot and speaker-fallback matrices.
5. Repair documented responsive Scanner layout and extract its platform lifecycle into an injected service.
6. Evaluate false alerts and broad fusion compatibility in realistic scenes.
7. If approved, execute a genuine privacy-reviewed household fine-tuning experiment with baseline comparison and export lineage.
8. Investigate smaller/quantized artifacts only with proper calibration, tensor parity and target-device testing.
9. Treat face identification, metric-depth hardware, route planning and continuous background operation as separate future scope, not existing features.
10. Finish production release/signing/distribution and operational documentation before claiming a production-ready assistive product.

## 33. Glossary

| Term | Simple explanation |
|---|---|
| Inference | Using an existing model to predict from an input |
| Training | Updating model parameters using a defined learning process |
| Fine-tuning | Further training pretrained parameters for a defined objective/data |
| Checkpoint | Saved model weights/state from training |
| Export | Converting a model into a runtime-compatible artifact |
| FP32 | 32-bit floating-point numerical representation |
| Quantization | Lower-precision numerical representation, requiring appropriate validation |
| Tensor | Multi-dimensional numerical array passed into/out of a model |
| Letterbox | Aspect-preserving resize with padding |
| Bounding box | Rectangle describing a predicted object's image location |
| Confidence threshold | Minimum score accepted by a filter |
| NMS | Removal of redundant overlapping candidate detections |
| IoU | Box-overlap ratio |
| Temporal stability | Requiring evidence across successive processed frames |
| Cooldown | Waiting interval before repeating an alert |
| Latency | Time taken for an operation or end-to-end response |
| Frame age | How old a captured frame is at a measured pipeline point |
| FPS | Frames per second, with the measured stage explicitly named |
| OCR | Optical character recognition: image to text |
| ASR / STT | Automatic speech recognition / speech to text |
| TTS | Text to speech |
| LLM | Language model used for text generation/reasoning |
| Vosk / Whisper | Different speech-recognition systems used in different paths |
| LAN | Local area network |
| DHCP | Automatic allocation of network addresses |
| mDNS / NSD | Local service naming/discovery mechanisms |
| WebSocket | Persistent bidirectional application connection |
| HMAC | Secret-key-based message authentication |
| Nonce | Fresh challenge value used to constrain reuse/replay |
| Keystore | Android facility protecting cryptographic keys |
| Dependency injection | Supplying services through interfaces instead of hardwiring them |
| State machine | Explicit allowed states and transitions for an operation |
| MethodChannel | Flutter/native messaging bridge |
| Ground truth | Reviewed reference annotations used for evaluation |
| Data leakage | Training/tuning knowledge incorrectly contaminating evaluation |
| Domain shift | Differences between training scenes and actual use conditions |

## 34. Source map and evidence provenance

This guide is self-contained; the following repository paths help a developer audit it. They are source locators, not required attachments for the GPT tutor.

| Topic | Repository evidence |
|---|---|
| Scope and approved exceptions | `AGENTS.md`, `docs/specification-baseline.md`, accepted `docs/decision-log.md` records |
| Latest implementation/evidence | `docs/PROJECT_STATUS.md`, `docs/CURRENT_MODULE.md`, `docs/requirements-traceability.md` |
| Architecture and known exceptions | `docs/architecture.md`, `docs/KNOWN_ISSUES.md` |
| Flutter dependencies | `mobile_app/pubspec.yaml`, `mobile_app/pubspec.lock` |
| Native runtime dependencies | `mobile_app/android/app/build.gradle.kts` |
| Routes | `mobile_app/lib/app/router/route_paths.dart`, `app_router.dart` |
| Mobile model identity | `mobile_app/assets/models/model_metadata.json`, `household_model_metadata.json` |
| Mobile native inference | `mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/InferenceHandler.kt` |
| Mobile parsing/fusion | `mobile_app/lib/app/detection_providers.dart`, domain household/fusion services |
| Relative risk | `mobile_app/lib/infrastructure/detection/obstacle_risk_assessor.dart` |
| Detection/alert design | `docs/detection-pipeline.md`, `docs/alert-engine.md` |
| Pi model contract | `raspberry_pi/model/README.md`, `raspberry_pi/model/SHA256SUMS` |
| Pi runtime/control | `raspberry_pi/src/ai_blind_pi/` and existing installer/systemd files |
| Physical Pixel/Pi restoration | `docs/PIXEL_PI_RESTORE_2026-10-22.md`, Module 76 |
| Latest local command evidence | `docs/VISION_AI_RELIABILITY_2026-10-21.md`, Module 75 |
| Smart AI circle/setup/cues | `docs/SMART_AI_CIRCLE_2026-10-20.md`, `SMART_AI_READY_CUE_2026-10-21.md`, `SMART_AI_FRESH_PHONE_2026-10-21.md` |
| Cloud speech/answer boundaries | `docs/SMART_AI_CLOUD_AUDIO_2026-10-19.md`, approved ADR-070/071/072/073/075 |
| Paired laptop speech | `docs/SMART_AI_SPEECH_VERIFICATION_2026-10-16.md`, backend config/README |
| OCR script and implementation | `mobile_app/lib/infrastructure/ocr/ml_kit_ocr_service.dart`, reader/scanner sources |
| Fine-tuning evidence gap | ISSUE-065 in `docs/KNOWN_ISSUES.md`; current pretrained source metadata |

Older brief material dated 12 October contains owner-attributed fine-tuning wording and older provider/acceptance descriptions. Use this 22 October guide for current study/presentation claims. Historical records remain useful as dated evidence but do not override newer verified boundaries.

Official upstream links in Sections 9, 15 and 23 explain the model family, power requirements and training/validation tools. They do not certify this project, its accuracy, a custom training run or suitability as a sole mobility aid.

## 35. Questions only you can answer before a final academic submission

Confirm your actual individual/team role, any external development assistance, institution-required disclosures, any real training artifacts stored outside this workspace, and any genuine participant study/ethics approval. None of those facts should be invented by a GPT tutor from implementation code.

If additional evidence becomes available, add a dated amendment identifying the exact artifact/result and its limits. Until then, present verified integration and observed behavior confidently, and describe uncompleted experiments as future work.
