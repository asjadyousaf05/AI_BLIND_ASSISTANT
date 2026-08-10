# Project Status

Last updated: 2026-08-09

## Overview

| Field | Status |
|---|---|
| Current work | Module 23 integrated verification and Android release |
| Overall state | Mobile and Wearable software implemented; signed ARM64 APK delivered; physical acceptance open |
| Flutter / Dart | Flutter 3.44.5 stable / Dart 3.12.2 |
| Android | application ID `com.example.ai_blind_assistant`; min SDK 24; target SDK 36; ARM64 release |
| State / DI / routing | Riverpod 3.3.2 and centralized named routes |
| Mobile camera/runtime | CameraX + LiteRT 2.1.5 CPU/XNNPACK |
| Mobile model | Official YOLOv8n COCO LiteRT FP32 320, bundled offline |
| Wearable runtime | Python 3.11+, Picamera2, NCNN on Linux aarch64, espeak-ng |
| Wearable model | YOLOv8n Open Images V7 NCNN FP32 320, 601 metadata labels |
| Wearable protocol | Authenticated local WebSocket v1, cross-process simulator verified |
| Release | locally signed ARM64 APK, v2 signature, release assets verified |
| Git state | Workspace is not a Git repository |

## Product Capabilities

Mobile Mode uses the existing layered Riverpod/controller architecture to gate
CameraX behind runtime permission, process stride-aware YUV frames through a
single background LiteRT inference owner, parse the real YOLO tensor, filter and
stabilize detections, and coordinate concise local speech and finite vibration.
It supports start, explicit pause, resume, stop, lifecycle pause, model/camera
errors, saved sensitivity/feedback settings, and complete resource release.

Wearable Mode uses Android NSD, remembered and manual local endpoints,
short-lived pairing, Android Keystore-backed credentials, authenticated typed
WebSockets, acknowledgements, heartbeats, replay protection, settings conflict
resolution, bounded reconnect, compact OIV7 events, and truthful health/error
states. The Pi service owns its detector, camera queue, persisted settings, and
local speech, so a simulated phone disconnect does not stop active assistance.

The native Stitch-inspired interface, one Riverpod DI system, named routing,
settings persistence, help/safety content, and Mobile/Pi isolation are
preserved. Saved high contrast, large text, and reduced-motion preferences are
now applied globally. No camera frame is transported or stored.

## Latest Verification

- `flutter pub get --offline`: passed.
- Dart formatting: 145 files checked, 0 changes.
- `flutter analyze --no-pub`: no issues.
- Flutter tests: all 146 passed, including the actual Python service simulator.
- Python compileall/Ruff: passed; all 14 pytest tests passed.
- ARM64 debug build: passed.
- ARM64 release build: passed and locally release-signed.
- Release package: `1.0.1` (`2002` split version code), min SDK 24, target 36,
  `arm64-v8a`, approximately 43 MiB, zipaligned, one RSA-3072 signer.
- Mobile camera initialization now tries every Android-reported rear camera and
  preserves bounded CameraX error codes/descriptions instead of hiding them.
- Release artifact contains the exact Mobile model, labels, and metadata.
- `adb devices -l`: no Android target; installation/launch not performed.
- Pi probe: `rpi3-ml.local` resolved to its current LAN address and TCP 22 was
  reachable, but BatchMode SSH was denied; no credential was requested/stored.
  No systemd, NCNN, camera, local-audio, or physical-LAN claim is made.

## Open Physical Acceptance

| Gate | Still required |
|---|---|
| Android phone | permission matrix, real boxes, TTS, vibration, TalkBack, text/display scaling, offline cold start, lifecycle/rapid cycles, thermal/performance |
| Raspberry Pi | deployment, Pi-side service validation, model load/live inference, local audio, physical discovery/pairing/reconnect, reboot/IP-change/WAN-off matrix |
| OV5647 | two separate capture sessions; report any CSI timeout unchanged |
| Performance | real phone and Pi mean/p95 inference, approximate FPS, memory, battery/temperature/throttling |
| Wearable haptics | no motor/circuit/pin was specified; UI truthfully reports unavailable |

## Safety and Security Boundary

- Processing is local; normal assistance requires no internet or cloud service.
- Protocol v1 authenticates and integrity-protects private-LAN messages but plain
  WebSocket is not confidential. Pair only on a trusted LAN and never expose or
  port-forward the service.
- Secrets are ignored, never logged, and stored through Android Keystore or
  owner-readable Pi state. The local release keystore must be securely backed up.
- Monocular boxes are relative visual warnings, never metric distance.
- This assistive aid does not replace a cane, guide dog, mobility training,
  human assistance, environmental awareness, or user judgment.

## Exact Next Action

Install `deliverables/AI-Blind-Assistant.apk` on one authorized ARM64 phone and
execute `docs/RELEASE_CHECKLIST.md`. Then authorize SSH, deploy the Pi service,
and run the exact physical procedures in `docs/wearable-mode.md`.
