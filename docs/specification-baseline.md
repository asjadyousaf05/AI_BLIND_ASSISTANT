# AI Blind Assistant Specification Baseline

## Owner-approved Vision AI reliability refinement — 2026-10-21

ADR-076 authorizes local listening recovery/readiness and conservative command
handling for the owner's 2026-10-22 demo. Preserve foreground-only on-phone speech,
deterministic controls, existing engines/models and all Smart AI provider/key/
consent boundaries. Require truthful resume, bounded recovery, cancellation of
stale starts, optional local readiness cues and an accessible restart. A command
with missing-word markers or negation must not become a positive action. Keep
ordinary listening paused during spoken feedback; document when to speak. Automated
checks are separate from physical accent/noise/haptic/latency acceptance. Do not
claim perfect or error-free recognition.

## Owner-approved cross-phone Smart AI consistency — 2026-10-21

ADR-075 keeps the circle visible on fresh phones before personal cloud setup.
Disable question capture/submission until personal key entry and existing explicit
provider-specific consent; keep local app commands, spoken setup guidance and cue
testing available without an API. Existing saved Gemini/laptop modes are restored;
fresh users may choose them explicitly. No key transfer/embedding or silent
provider selection, and no Vision AI/native/model/network policy change.

## Owner-approved Vision AI command feedback — 2026-10-21

ADR-074 authorizes spoken progress and truthful outcomes for local Raspberry Pi
connection/discovery and Mobile Mode startup. Resolve deterministic commands using
the visible screen; support bounded polite navigation, open setting/about page,
and Listen Vision AI. Smart AI's foreground idle/paused local listener accepts
go back/go home without holding the circle or another wake. Explicit circle
recording owns the microphone exclusively; ordinary local speech never starts a
cloud interaction. Preserve all provider/key/audio bounds and offline vision.
Previous Smart-AI-only change restrictions apply to their historical modules;
this request explicitly extends the local Vision AI command path. Physical
recognition/noise/output acceptance remains separate from software verification.

## Owner-approved Smart AI listening cue — 2026-10-21

ADR-073 refines only Smart AI's recording-ready feedback. After the microphone
actually begins recording, emit one bounded accessibility vibration and a short
local prompt chime, then the user speaks. Release-to-send, pause/resume, language
and foreground local controls retain their approved behavior. The labelled test
action checks both cues without recording or API use. Visible/spoken/TalkBack
instructions explain the cue. Respect device media volume/routing/DND and expose
actual cue-start failures without disabling recording. Cancel/submit/Activity
pause/exit stop feedback; no background output or delayed replacement cleanup.
This replaces the earlier 180 ms vibration-only adapter; it adds no cloud or
Vision AI change. Owner will test the APK later; physical output is unverified.

## Owner-approved Smart AI bilingual circle — 2026-10-20

ADR-072 refines the configured foreground Smart AI view. Preserve the exact base
prompt; a separate latest-turn language instruction and existing installed offline
voices support English/Urdu replies. Automatic Whisper language identification
can mishear short English speech as Urdu. Provide accessible Auto/English/Urdu
choices; explicit choices set en/ur on the same transcription request and carry
through to the answer. No retry, second provider or guarantee of automatic ASR.

Hold the large circle one second, wait for its 180 ms listening pulse, speak and
release to submit once. Tap a reply to pause/resume locally from its last reported
word; hold again to interrupt. Named buttons/semantic tap/keyboard, spoken help,
Test listening vibration and Back to Home provide accessible alternatives.
The manual-capture cue is independent of obstacle-alert settings and changes no
Vision AI preference. Early setup release, cancelled touches and backgrounding
discard clips; existing 30-second capture and network bounds remain.

After the initial 1.4.13 check, the owner explicitly authorizes local Vision AI
to remain available alongside button-only Smart AI. Enable a foreground-only
local exact goodbye Smart AI listener without a button or wake prefix. It needs
no API. Release the native recognizer microphone during button capture, resume
it afterwards and restore the saved hands-free preference on exit. A narrow
button-mode guard prevents ordinary local speech from invoking the legacy Smart
AI conversation path. Reject speaker echo and incidental mentions. Typed/recorded
goodbye remain deterministic alternatives; recorded goodbye deletes its STT clip
before interpretation. Restore audio and return through the existing Home route.
This narrow shared-bridge/native-handler/kernel integration supersedes earlier
screen-wide wake-pause/recorded-only-exit wording. It does not change Vision AI
base command/wake grammars, detection models, resolver, backend or Pi; no cloud
wake, background listener, camera upload or unprompted cloud request is allowed.

## Owner-approved Groq speech and answers — 2026-10-19

After AgentRouter returned `unauthorized client detected`, the owner explicitly
selected "Use Groq for speech and answers". The foreground Smart AI pipeline
may therefore send the transcript and the same bounded conversation history to
`https://api.groq.com/openai/v1/chat/completions`, model `openai/gpt-oss-20b`,
using the saved personal Groq key. Whisper large v3, the exact original system
prompt, phone-local TTS, temporary-file cleanup and Vision AI isolation remain.
Use low reasoning effort, exclude reasoning from returned speech, and cap
generation at 512 completion tokens including internal reasoning.

This is an explicit provider selection, never an automatic fallback. Renew the
destination-specific in-app consent before saving; keep selection encrypted.
Older configuration without a provider field stays AgentRouter until the owner
selects otherwise. Groq mode requires no AgentRouter key and must never call
AgentRouter. Free-plan access has provider/account quotas; no unlimited or
guaranteed-latency claim. ADR-071 records the decision and live access evidence.

## Owner-Authorized Smart AI Groq/AgentRouter Pipeline — 2026-10-19

The owner explicitly requests foreground Smart AI speech capture → Groq Audio
Transcription using `whisper-large-v3` → AgentRouter using `deepseek-v4-flash` →
phone speech, while leaving Vision AI unchanged. This is an optional personal-
key mode after explicit in-app audio/text destination disclosure and agreement.
It alone supersedes older cloud-audio prohibitions. No existing Vision AI,
wake recognizer, Mobile/Pi detection, OCR or backend provider is migrated.

Use existing native 16 kHz mono AAC/M4A (accepted by Groq) with 30-second/4 MB
caps; no extra conversion worker. Upload after Stop/Send or the recording cap.
Delete the phone clip as soon as transcription finishes, including failure and
cancellation paths. Provider retention is governed by their policies; local
deletion must not be described as provider deletion. Keys are owner-entered,
separately Keystore-encrypted, obscured and never bundled/logged. Recording is
gesture-initiated and foreground-only. No background or cloud wake listening.

Direct fixed HTTPS endpoints are Groq `/openai/v1/audio/transcriptions` and the
owner-specified `https://agentrouter.org/v1/chat/completions`. Use the requested
exact system prompt in ADR-070, limited text/history/output and async I/O.
No model/host substitution, redirects, automatic retries or model tools.
Deterministic local controls take priority after transcription; cloud responses
are conversation only. Shared local audio ownership pauses wake listening only
while this Smart AI screen is active and restores its saved preference on exit.
Requests are sequential, cancellable and deadline-bounded, with late replies
ignored. Core vision/offline behavior stays independent. This is file-based
turn-taking; no full-duplex streaming or measured real-time latency is claimed.

This mode takes precedence only on the Smart AI screen when configured;
removing its keys restores the previous Gemini/laptop mode and preserves their
credentials. Vision AI's existing command/conversation selection is unchanged.

## Owner-Authorized Laptop-Free Text Assistant — 2026-10-18/19

The owner requests optional API conversation without the laptop, alongside
phone-hotspot Pi operation. Personal Gemini mode may send typed/unmatched
phone-transcribed conversation text and at most ten recent conversation
messages directly over HTTPS to Google's fixed Gemini endpoint after an
explicit in-app disclosure and agreement. The owner supplies their own key;
it is encrypted by Android Keystore through the existing secure-storage channel,
never embedded in source/APK or sent to the laptop. Removal clears that key and
the in-memory conversation while preserving Pi/laptop trust.

This narrowly supersedes the backend-only API-key storage and laptop-only
conversation rules. Gemini receives no camera frames or raw audio. Phone-local
recognition and TTS support direct mode; laptop Whisper remains available only
in the already-approved paired laptop mode. Deterministic app controls take
priority and cloud output can never propose or execute tools. Direct mode has
no automatic Ollama fallback without a reachable laptop; errors must say so
truthfully. Core Mobile/Pi/OCR/control workflows remain independent and offline.
Free-tier content-use and quota limits must be disclosed. This is personal-key
operation, not authorization to distribute an application-wide client secret.

## Owner-Authorized Smart AI Speech Amendment — 2026-10-16

The owner explicitly selected: “Use paired-laptop Whisper for Smart AI speech;
disclose it clearly and delete clips after processing.” In paired Smart AI,
the foreground Speak button may record up to 30 seconds/4 MB and send temporary
audio only to the authenticated private-LAN laptop for local Whisper. Disclose
this before the control; remove phone and laptop clips after processing,
including failed/cancelled sessions. Retention and audio logging are prohibited.

This narrowly supersedes ADR-043's phone-only rule for paired manual Smart AI
speech. Hands-free/wake speech, unpaired manual controls and core assistance
stay phone-local. Camera frames and raw audio must never go to Gemini or any
cloud service. Gemini may receive only permitted conversation text. Pairing,
foreground-only capture and deterministic command/confirmation rules remain.

## Owner-Authorized Scope Amendment — 2026-08-14

The owner explicitly authorized a foreground hands-free in-app voice assistant,
local Ollama reasoning, and optional Gemini reasoning with automatic Ollama
fallback. After one microphone grant, the open app may listen locally for a
wake phrase and accept spoken commands and spoken confirmation without touch.
This amendment supersedes the original no-authentication/no-cloud constraint
only for the paired assistant feature. Core camera inference, detection,
Raspberry Pi assistance, safety alerts, UI assets, and settings remain local and
fully usable without Gemini or internet access.

The amendment does not authorize camera/frame upload, raw-audio cloud upload,
background or lock-screen listening, face identification, analytics, Firebase,
remote configuration, OS-wide control, arbitrary model tool execution, or
removal of confirmation for sensitive actions. Wake recognition and app-command
transcription stay on the phone. Gemini may receive only unmatched transcript
or typed conversation text after explicit disclosure. Without a Gemini key,
optional general-conversation reasoning stays on the paired laptop through
Ollama.

## Project Vision

AI Blind Assistant is an offline Android assistive application for blind and visually impaired users. It uses a phone camera and lightweight on-device object detection to identify relevant objects and likely obstacles, then communicates actionable feedback through offline audio and bounded vibration patterns.

The application is an assistive aid. It must not claim to replace a white cane, guide dog, trained human assistance, professional orientation and mobility support, or user judgment.

## Problem Definition

Blind and visually impaired users may need quick awareness of nearby objects or obstacles while moving through everyday environments. Cloud-based vision systems can introduce privacy, latency, connectivity, and cost concerns. This project focuses on a local-first Android application that can run without internet access and provide timely, accessible feedback.

## Primary User

The primary user is a blind or visually impaired Android user who relies on TalkBack, audio prompts, haptic feedback, or a combination of both. The user may operate the phone directly in Mobile Mode first, and may later connect an optional wearable Raspberry Pi camera device.

## Finalized In-Scope Features

- Android-first Flutter application with native Flutter widgets.
- Mobile Mode using the Android phone camera.
- On-device generic object detection.
- Generic person detection using the model's `person` class.
- Estimated obstacle risk based on detection result properties.
- Offline text-to-speech feedback.
- Structured vibration feedback with bounded patterns and cooldowns.
- TalkBack-compatible screens, labels, focus order, and touch targets.
- Local settings storage for detection and feedback preferences.
- Raspberry Pi Mode as a later optional wearable mode after Mobile Mode is stable.
- Error handling for denied permissions, unavailable camera, model failures, and Raspberry Pi connection loss.
- Owner-authorized typed, foreground wake-word, and manual push-to-talk
  assistant with bundled phone-local speech for app control and optional
  laptop-local Ollama conversation.
- Optional Gemini text reasoning with per-request Ollama fallback.
- No cloud vision processing and no raw camera frame transmission.

## Deferred Features

- Familiar-face or familiar-person identification.
- Exact physical distance measurement.
- Final Raspberry Pi hardware acceptance until Mobile Mode and wearable hardware
  are physically validated.
- OCR or text recognition, unless explicitly approved in a later module.
- Advanced obstacle tracking beyond basic persistence across frames.
- Custom local model training or model optimization work.
- Production branding, app icon replacement, and release signing.

## Out-of-Scope Features

- WebView-based final UI.
- Video uploading, video recording, image uploading, or remote image processing.
- Accounts, profiles, roles, remote identity, or multi-user workflows. Local
  one-device Pi/assistant pairing is the narrow owner-authorized exception.
- Firebase, cloud analytics, crash analytics, ad SDKs, or telemetry.
- Familiar-person recognition in the first production-quality version.
- Claims that the app replaces mobility aids or professional support.
- Continuous uncontrolled vibration.
- Any feature that requires internet access for the core assistive workflow.

## Mandatory Scope Decisions

1. The first production-quality version will perform generic object detection, not familiar-person identification.
2. "Person recognition" means detecting the generic person class.
3. Familiar-face identification is a future enhancement.
4. The system will provide estimated obstacle risk, not exact physical distance.
5. Risk estimation may use bounding-box area, frame position, class priority, and persistence across frames.
6. Mobile Mode is the first implementation priority.
7. Raspberry Pi Mode is implemented only after Mobile Mode is stable.
8. Core Mobile/Wearable assistance and the Ollama assistant path must remain
   functional without an internet connection after local models are prepared.
9. No raw camera frames will leave the device.
10. The interface must work with TalkBack.
11. Stitch HTML is a design reference and must be translated into Flutter widgets rather than embedded in a WebView.
12. Continuous uncontrolled vibration is prohibited. Alerts will use bounded vibration patterns and cooldowns.
13. The app is an assistive aid and must not claim to replace a white cane, guide dog, trained human assistance, or professional mobility support.

## Assumptions

- The target platform for this FYP is Android.
- Flutter is the application framework.
- The first model will be a lightweight on-device detector packaged with the app in a later module.
- The initial model labels will include common object classes and a generic `person` class.
- Offline TTS will use Android system text-to-speech voices or another local-only TTS strategy.
- Vibration feedback will depend on Android device haptic capability and user settings.
- Raspberry Pi Mode will require a local connection method, but no internet dependency.
- Stitch-generated HTML and PNG screenshots are design references, not production UI code.

## Constraints

- No cloud inference.
- No raw camera frames may leave the device.
- No video recording or upload.
- No analytics, authentication, Firebase, or user tracking.
- No AI inference pipeline implementation in Module 1.
- Mobile Mode must be delivered before Raspberry Pi Mode.
- Camera, inference, speech, vibration, storage, and networking logic must not live inside Flutter screen widgets.
- UI must remain accessible under TalkBack and with larger Android font sizes.
- Any remote Stitch image, font, or CDN reference must be replaced by local Flutter assets, bundled fonts, or Material icons before production use.

## Safety Limitations

- Detection may miss objects, misclassify objects, or produce delayed feedback.
- Estimated risk is not exact distance.
- Camera view can be obstructed by hand position, lighting, motion blur, glare, or device orientation.
- Haptic and audio feedback may be unavailable if the device is muted, in do-not-disturb mode, lacks haptic hardware, or has accessibility settings that override app behavior.
- The app must communicate that it supports awareness only and does not replace established mobility aids.

## Terminology

- Mobile Mode: The Android phone camera performs capture and on-device inference.
- Raspberry Pi Mode: An optional wearable Raspberry Pi and camera provide external camera input after Mobile Mode is stable.
- Generic object detection: Detection of model classes such as chair, door, bottle, car, and person.
- Person detection: Detection of a generic `person` class, not identification of a known person.
- Familiar-face identification: Matching a detected face to a stored identity. This is deferred.
- Estimated obstacle risk: A categorical risk result derived from class priority, bounding-box area, screen position, and persistence.
- Alert cooldown: A minimum interval that prevents repetitive or continuous alerts.
- Bounded vibration pattern: A finite haptic sequence with a defined maximum duration.

## Resolved Contradictions

- Stitch permissions copy mentions taking and sharing photos and profile personalization. The final app must request camera access only for local assistive detection.
- Stitch connection-error copy mentions checking the internet connection. The final app is offline-first; Raspberry Pi connection errors must refer to local device connection status, not internet access.
- Stitch about screen uses the name "Lumina AI" and version "2.4.0". The project name is AI Blind Assistant; production copy must use the FYP name unless a branding decision changes it.
- Stitch mode-selection copy mentions text recognition. Initial scope is generic object detection only. OCR or text recognition is deferred until explicitly approved.
- "Person recognition" is resolved as generic person-class detection, not familiar-person identification.
- "Distance" is resolved as estimated risk or estimated proximity, not exact metric distance.

## Remaining Open Questions

- Which object-detection model and label set will be selected for the first mobile prototype.
- Whether the final FYP demonstration requires OCR after object detection is complete.
- Which local storage package will be used for settings.
- Which Android TTS and vibration APIs will be used from Flutter.
- Which local transport will be used for Raspberry Pi Mode.
- Whether the Lexend font should be bundled locally or replaced with a system font for accessibility and package simplicity.

None of these questions blocks Module 2 native Flutter UI migration.
