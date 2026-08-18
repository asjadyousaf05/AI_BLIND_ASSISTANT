# AI Blind Assistant Specification Baseline

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
