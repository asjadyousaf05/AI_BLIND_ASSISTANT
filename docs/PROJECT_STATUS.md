# Project Status

Last updated: 2026-08-20

## Overview

| Field | Status |
|---|---|
| Current work | Module 57 exclusive code-free Raspberry Pi enrollment |
| Overall state | Cross-stack implementation/release verified; physical Pi connection blocked by endpoint/network state |
| Mobile stack | Flutter 3.44.5 / Dart 3.12.2, Android min SDK 24, target 36 |
| Architecture | Feature-first layers, Riverpod DI/state, centralized named routes and one voice/TTS owner |
| Mobile assistance | CameraX, bundled YOLO/LiteRT, local TTS, bounded haptics |
| Wearable assistance | Exclusive first-phone enrollment, authenticated local WebSocket v1, Pi NCNN/Picamera2, phone-priority TTS with Pi fallback |
| Offline voice | One strict branded wake per foreground session, focused contextual grammars until goodbye |
| Smart AI | Same phone-local Vosk input; unmatched transcript text to paired Gemini-first/Ollama-fallback backend |
| Release metadata | `1.4.2+2042`; ARM64 installed on TECNO BG6 as ABI-adjusted code `4042` |

## Implemented Capabilities

Wearable Mode is configured for `10.141.17.148:8765`, retains mDNS/manual
private-host discovery, and now exposes no Pi pairing-code field. On first use,
one `Connect & Start Detection` action sends an exclusive enrollment request,
receives a random application credential, stores it through Android Keystore,
authenticates, synchronizes settings, and starts the Pi assistance pipeline.
Later sessions reuse the credential automatically.

The Pi permits this operation only when first-client enrollment is explicitly
enabled, the peer is private/loopback, and no non-revoked phone credential
exists. Enrollment is atomic and then closes. All later messages retain
nonce-bound HMAC authentication, integrity, replay protection and revocation.
Linux login credentials are not used by the app and no SSH code is packaged.
This first-use mechanism is trust-on-first-use and must run on an
owner-controlled private network.

The Pi keeps camera capture and NCNN inference local. Raw frames never leave
the Pi. Stability/cooldown-gated priority events target the authenticated phone
and Flutter speaks relative-position alerts through `VisionVoiceKernelV3`; Pi
speech remains the disconnect fallback. Ordinary telemetry stays silent.

The foreground offline assistant and Document Scanner capabilities from
Modules 53-55 remain present and unchanged by Module 57.

## Latest Evidence

- Flutter analyzer: 0 findings; full Flutter suite: 319 passed, 0 failed,
  including Flutter against an actual Python simulator process.
- Pi Ruff: clean; Pi suite: 15 passed, 46 Python 3.14 upstream warnings.
- Android `:app:testDebugUnitTest`: build successful.
- Release splits: 113.4 MB ARM, 125.8 MB ARM64, 130.7 MB x86_64.
- ARM64 SHA-256:
  `a4ab50e4ef27c73104eec96c11854dbb088a5e407ecf175eb87d8abbf6a8717c`.
- TECNO BG6: data-preserving release install succeeded as `1.4.2` / code
  `4042`; process alive/focused and no app-scoped fatal marker found.
- Pi endpoint retry: phone ping 2/2 lost; Mac TCP 22 and 8765 timed out.
- Network mismatch remains: phone Wi-Fi `10.141.10.93/21`; supplied Pi
  `10.141.17.148` is outside that local `/21`.

## Open Acceptance and Limitations

| Gate | Required evidence |
|---|---|
| Pi reachability | Pi and phone on one non-isolated LAN; current IP and TCP 8765 reachable |
| Pi deployment | matching Module 57 service/config/model installed; NCNN validation and two OV5647 sessions |
| Exclusive enrollment | first phone succeeds, simultaneous/second phone rejected, revoke-all recovery observed physically |
| Wearable phone audio | Connect & Start, priority event, phone utterance, media-volume/TTS failure and disconnect fallback |
| Wearable resilience | Wi-Fi interruption, reconnect, Pi reboot/address change, revocation, WAN-disabled session |
| Android voice/crash | physical accent/noise/false-command and repeated lifecycle/tombstone matrix |
| Accessibility | physical TalkBack focus/order/live announcements and 2× text |
| Performance | phone/Pi latency, FPS, memory, temperature, throttling, battery/power |

Code-free first enrollment does not mean unauthenticated ongoing control. It is
exclusive trust-on-first-use. Protocol v1 remains authenticated but
unencrypted, so never use public Wi-Fi or port-forward TCP 8765. The product is
an assistive aid, not a replacement for a cane, guide dog, mobility training,
human assistance, situational awareness, or user judgment.

## Exact Next Action

Place the Pi and TECNO BG6 on the same owner-controlled private router/hotspot,
confirm the current Pi address and TCP 8765, deploy/start the matching Module
57 service with first-client enrollment enabled, and tap `Connect & Start
Detection`. Record first enrollment, authenticated running state, phone audio,
second-client rejection, disconnect fallback and Pi camera/model logs.
