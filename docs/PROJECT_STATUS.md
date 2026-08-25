# Project Status

Last updated: 2026-08-25

## Overview

| Field | Status |
|---|---|
| Current work | Module 58 dynamic Pi discovery and public-WiFi SSH tunnel fallback |
| Overall state | Cross-stack implementation verified; physical Pi connection pending deployment |
| Mobile stack | Flutter 3.44.5 / Dart 3.12.2, Android min SDK 24, target 36 |
| Architecture | Feature-first layers, Riverpod DI/state, centralized named routes and one voice/TTS owner |
| Mobile assistance | CameraX, bundled YOLO/LiteRT, local TTS, bounded haptics |
| Wearable assistance | mDNS hostname default, SSH tunnel fallback, exclusive first-phone enrollment, authenticated local WebSocket v1, Pi NCNN/Picamera2, phone-priority TTS with Pi fallback |
| Offline voice | One strict branded wake per foreground session, focused contextual grammars until goodbye |
| Smart AI | Same phone-local Vosk input; unmatched transcript text to paired Gemini-first/Ollama-fallback backend |
| Release metadata | `1.4.2+2042`; ARM64 installed on TECNO BG6 as ABI-adjusted code `4042` |

## Implemented Capabilities

Wearable Mode default host is now `rpi3-ml.local` (Pi mDNS hostname). On the
same LAN the phone resolves the hostname automatically via Android NSD. On
public/isolated WiFi the user runs `reverse_tunnel.sh` on the Pi to forward
port 8765 through the laptop and enters the laptop IP in the app host field.

The Pi permits first enrollment only when explicitly enabled, the peer is
private/loopback, and no non-revoked phone credential exists. Enrollment is
atomic; all later messages retain nonce-bound HMAC authentication, integrity,
replay protection, and revocation. Linux login credentials are not used by the
app and no SSH code is packaged in Android.

The Pi keeps camera capture and NCNN inference local. Raw frames never leave
the Pi. Priority events target the authenticated phone and Flutter speaks
relative-position alerts through `VisionVoiceKernelV3`; Pi speech remains the
disconnect fallback.

The foreground offline assistant and Document Scanner capabilities from
Modules 53-55 remain present and unchanged.

## Latest Evidence

- Flutter analyzer: 0 findings; full Flutter suite: 318 passed, 0 failed.
- Pi Ruff: clean; Pi suite: 15 passed, 0 failed.
- Dart formatting: 226 files, 0 changed.

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

Same WiFi as Pi (home router / personal hotspot):
1. `sh raspberry_pi/scripts/deploy.sh asjad rpi3-ml auto`
2. `ssh asjad@rpi3-ml sudo systemctl restart ai-blind-assistant-pi`
3. App host shows `rpi3-ml.local` — tap Connect & Start Detection.

Public/university WiFi:
1. Deploy as above.
2. Find laptop LAN IP: `ifconfig | grep inet`.
3. On Pi: `sh /opt/ai-blind-assistant/service/scripts/reverse_tunnel.sh asjad <LAPTOP_LAN_IP>`
4. In app: change host to `<LAPTOP_LAN_IP>`, tap Connect & Start Detection.

Record enrollment, running detection, phone-speaker alert, and TalkBack focus.
