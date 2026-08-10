# Testing

Last reviewed: 2026-08-09

## Strategy

Pure preprocessing decisions, YOLO parsing, stability, risk, cooldown, state
coordination, settings, routes, semantics, and error behavior are automated.
Camera sensor behavior, installed Android TTS voices, physical vibration,
TalkBack, box alignment, thermals, and sustained performance require a physical
Android phone and must not be inferred from mocks or an emulator.

Test naming:

- `UT-AREA-###`: unit/controller test;
- `WT-AREA-###`: widget/accessibility test;
- `IT-AREA-###`: Android integration test;
- `MT-AREA-###`: manual physical-device test.

## Current Automated Coverage

```text
test/
  accessibility/
  app/
  core/
  domain/
  features/
    camera/
    detection/
    feedback/
    inference/
    integration/
    permissions/
    settings/
integration_test/
test/features/wearable/
raspberry_pi/tests/
```

Important Mobile Mode coverage includes:

| Area | IDs | Evidence |
|---|---|---|
| Permission/lifecycle | `UT-PERM-001`–`012`, `UT-LIFECYCLE-001`–`002` | grant/deny/permanent denial and lifecycle transitions |
| Camera contract | `UT-CAM-001`–`008` | state, structured frame, callback, cleanup, bounded actionable CameraX errors |
| Model assets/metadata | `UT-MODEL-001`–`006` | final 12 MB model loads as a Flutter asset; labels and tensor metadata match; no INT8 claim |
| Inference controller | `UT-INFER-001`, `UT-INT-006`, `UT-INT-018` | output contract, real overlapping-frame drop guard, diagnostics |
| YOLO parsing | `UT-BBOX-001`–`005`, `UT-DET-001`, `UT-POST-001`–`010` | confidence, both layouts, NMS, invalid lengths, letterbox removal |
| Stability | `UT-STABILITY-001`–`003` | two-frame confirmation and spatial matching |
| Risk | `UT-RISK-001`–`010` | horizontal position, visual proximity, importance, no metric distance |
| Feedback | `UT-ALERT-001`–`012` | finite patterns, mode routing, cooldown, duplicates, priority, fallback, low-risk suppression |
| Full assistance state machine | `UT-INT-001`–`023` | start/stop/retry/pause/detach/errors/resources, delayed-stop cancellation, effective feedback, runtime camera shutdown |
| Accessibility/UI | `WT-ACC-001`–`002`, `WT-UI-001`–`008` | labels, routes, dynamic states, route-exit cleanup, 2.0 text scale |

Wearable coverage adds:

| Area | Evidence |
|---|---|
| Shared protocol/HMAC | strict serialization, fixed Python/Dart proof/tag vectors, malformed payloads |
| Security | pairing success/failure/expiry, replay rejection, revocation, signed sessions |
| Reliability | bounded retry/backoff, dedup/out-of-order rejection, idempotent command cache, lifecycle reconnect |
| Settings | deterministic conflict resolver, Pi atomic persistence, synchronized request/ack path |
| Pi engine | state transitions, phone-disconnect independence, OIV7 output parser/NMS, one-slot queue |
| Recovery/deployment | bounded camera error, hardened systemd assertions, checksum manifest, shell syntax |
| Accessibility | setup controls and truthful initial state semantics |
| Cross-stack E2E | actual Python service process: pair/auth/settings/start/event/disconnect/reconnect/pause/resume/stop/revoke |

## Latest Command Results

Executed on 2026-08-09 from `mobile_app/`:

| Command | Exact result |
|---|---|
| `flutter --no-version-check pub get --offline` | Passed; cached dependencies resolved. |
| `dart format lib test integration_test` then format check | Passed; 145 files checked, 0 outstanding changes. |
| `flutter --no-version-check analyze --no-pub` | Passed; no issues found. |
| `AIBA_PI_PYTHON=<test-venv>/bin/python flutter --no-version-check test --no-pub` | Passed; all 146 tests, including cross-stack wearable E2E. |
| `flutter --no-version-check build apk --debug --split-per-abi --target-platform android-arm64 --no-pub` | Passed; ARM64 APK created. |
| `flutter --no-version-check build apk --release --split-per-abi --target-platform android-arm64` | Passed; release-mode plugin registration excluded the test-only integration plugin and the signed ARM64 APK built. |
| `./gradlew :app:processReleaseMainManifest` | Passed; current release manifest includes camera/vibration plus local-LAN wearable network permissions. |
| `flutter --no-version-check test --no-pub integration_test` | Not an Android result: no device was present, Flutter selected macOS SDK, and the run was stopped. |

The debug APK contains the final model, labels, and metadata. `INTERNET` and
`ACCESS_NETWORK_STATE` are present in the current main/release manifest for the
separately implemented local-LAN wearable module; Mobile Mode has no network
dependency or runtime asset download.

The final release was additionally checked with Android build-tools 36:
`zipalign -c` passed; `apksigner verify --verbose --print-certs` passed with one
RSA-3072 signer and v2 signing; `aapt dump badging` reports package
`com.example.ai_blind_assistant`, version `1.0.1`/split code `2002`, min SDK 24,
target SDK 36, and ARM64 native code. Installation was not attempted because
`adb devices -l` returned no Android device.

Executed from the repository root for the Pi service:

| Command | Exact result |
|---|---|
| `python3 -m compileall -q raspberry_pi/src raspberry_pi/scripts` | Passed. |
| `<test-venv>/bin/ruff check raspberry_pi/src raspberry_pi/tests raspberry_pi/scripts` | Passed; all checks clean. |
| `<test-venv>/bin/python -m pytest raspberry_pi/tests` | Passed; all 14 tests. |
| `sh -n raspberry_pi/scripts/install.sh raspberry_pi/scripts/deploy.sh` | Passed. |
| `systemd-analyze verify ...` | Not available on macOS; the unit is parsed/asserted by pytest and still needs Pi-side validation. |

The Flutter wearable subset contains 10 tests. Its process E2E uses the same
Python package/server as deployment, not a second mock protocol. It validates
software integration only; simulator Car events are not camera/model evidence.

## Model Validation

The export script verifies the official weights SHA-256, inspects real tensor
metadata, allocates LiteRT tensors, and runs a warm-up. A reference parity run
on the official Ultralytics bus image produced three people and one bus from
both the PyTorch weights and final LiteRT asset.

This proves that the exported graph is operational and consistent at a basic
functional level. It is not an accuracy benchmark or physical camera test.

## Emulator Runtime Evidence

On the current ARM64 Android API 37 emulator `emulator-5554` smoke run:

- install and launch passed;
- CameraX opened a 640 x 480 stream;
- the bundled LiteRT loaded and XNNPACK delegated 254 of 256 graph nodes;
- Mobile Mode reached `Detecting`;
- no app-process fatal error was logged during that smoke path;
- the emulator later went offline, so sustained, current stop/resume/offline
  checks were not completed in this pass.

The virtual scene produced zero useful detections. It cannot validate box
alignment, real announcements/haptics, accuracy, or performance.

## Required Physical-device Tests

| Manual ID | Check | Pass criterion |
|---|---|---|
| `MT-PERM-001` | deny, grant, permanently deny | correct state and Open Settings action |
| `MT-CAM-001` | rear camera portrait/landscape | responsive preview and aligned boxes |
| `MT-DETECT-001` | representative COCO objects | detections originate from live frames and match visible objects |
| `MT-FEEDBACK-001` | audio/vibration/both | settings honored, short phrases, cooldown and bounded haptics |
| `MT-OFFLINE-001` | cold launch in airplane mode | Detecting works without network |
| `MT-LIFE-001` | background/resume and 20 rapid cycles | no crash, duplicate stream, or retained camera indicator |
| `MT-PERF-001` | sustained real-phone session | record mean/p95 inference, approximate FPS, memory, battery, thermal state |
| `MT-TALKBACK-001` | TalkBack and large text | logical focus, meaningful labels, live status and recovery controls |

No measured real-phone inference latency or FPS is currently available.

## Required Raspberry Pi / Wearable Tests

| Manual ID | Check | Pass criterion |
|---|---|---|
| `MT-PI-MODEL-001` | validate installed NCNN artifact | exact files/hashes/601 labels and NCNN load pass |
| `MT-PI-CAM-001` | two consecutive independent OV5647 sessions | both open/capture/close runs pass; report either failure honestly |
| `MT-PI-E2E-001` | physical phone pairing/control/events | mDNS and hostname/manual paths, signed ACKs, truthful status |
| `MT-PI-DISCONNECT-001` | phone Wi-Fi/background/process loss | Pi speech/assistance continues; bounded phone reconnect restores real state |
| `MT-PI-REBOOT-001` | Pi reboot/service restart/IP change | rediscovery/authentication/settings/status recover without fixed phone IP |
| `MT-PI-ERROR-001` | model/camera/auth/protocol failures | structured visible errors, bounded camera recovery, no crash loop |
| `MT-PI-OFFLINE-001` | WAN/mobile data disabled | local pairing/control/detection/feedback remains functional |
| `MT-PI-ACC-001` | TalkBack/large text/high contrast | logical focus, state announcements, controls and recovery readable |
| `MT-PI-PERF-001` | sustained real Pi inference | record mean/p95 latency, FPS, memory, temperature, throttling and power |

No Pi FPS, latency, camera stability, or audio-hardware result is currently
available because SSH authentication was unavailable.

## Privacy Checks

Code review and tests must continue to ensure that camera frames, image bytes,
face data, audio recordings, identifiers, Wi-Fi credentials, API keys, and
device secrets are neither logged nor stored. The current pipeline keeps frames
transient and has no camera-frame upload or remote inference path.
