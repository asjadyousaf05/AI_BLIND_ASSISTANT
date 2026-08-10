# Release Checklist

Last reviewed: 2026-08-09

## Delivered Build

| Property | Verified value |
|---|---|
| Artifact | `deliverables/AI-Blind-Assistant.apk` |
| ABI | ARM64-v8a |
| Package | `com.example.ai_blind_assistant` |
| App label | AI Blind Assistant |
| Version | `1.0.1` (split version code `2002`) |
| Android SDK | minimum 24; target 36 |
| Signing | local project RSA-3072 certificate; APK Signature Scheme v2 |
| Size | approximately 43 MiB |
| SHA-256 | `ae4e0fce3eb0d6c7cafa59581db99ca8f71d31ec7b7a5927ff141f8ab19d20da` |

`zipalign`, package metadata, certificate inspection, model assets, and the APK
signature have been verified. The original Gradle output remains under
`mobile_app/build/app/outputs/flutter-apk/`.

## Install and Launch

```bash
cd /Users/mm/AI_BLIND_ASSISTANT
adb devices -l
adb -s <android-device-id> install -r deliverables/AI-Blind-Assistant.apk
adb -s <android-device-id> shell monkey \
  -p com.example.ai_blind_assistant -c android.intent.category.LAUNCHER 1
```

An authorized line must end in `device`. No phone was connected during this
release pass, so installation and launch are not checked off.

## Automated Gates

- [x] Dependencies resolve offline.
- [x] Dart formatting is clean.
- [x] Flutter analysis reports no issues.
- [x] All 146 Flutter tests pass.
- [x] All 14 Pi Python tests pass; Ruff and compileall pass.
- [x] Flutter-to-Python pairing/control/event/reconnect simulation passes.
- [x] ARM64 debug and signed release builds pass.
- [x] Release APK is non-empty, aligned, signed, metadata-readable, and contains
      the bundled Mobile model/labels/metadata.
- [x] Stitch sources remain preserved.

## Physical Android Gates

- [ ] Install and launch without an immediate fatal crash.
- [ ] Grant/deny/permanently deny/revoke Camera and verify Open Settings.
- [ ] Verify real camera boxes in portrait and landscape.
- [ ] Verify useful COCO detections, concise local TTS, and bounded vibration.
- [ ] Verify sensitivity, cooldown, speech/vibration, high contrast, large text,
      and reduced-motion settings survive process restart.
- [ ] Verify pause/resume/stop, background/resume, and 20 rapid cycles.
- [ ] Verify Mobile Mode after cold start with Wi-Fi/mobile data disabled.
- [ ] Verify TalkBack order, labels, live statuses, and recovery actions.
- [ ] Record mean/p95 inference, approximate FPS, memory, battery, and thermal
      behavior from a sustained session.

## Physical Raspberry Pi Gates

- [ ] Deploy and validate the systemd unit as the restricted `aiba` user.
- [ ] Verify NCNN files, 601 Open Images labels, hashes, and model load.
- [ ] Run two independent OV5647 capture sessions; retain any CSI timeout result.
- [ ] Verify mDNS, remembered endpoint, hostname/manual fallback, pairing,
      authentication, settings ACK, control ACK, detections, alerts, and health.
- [ ] Verify phone Wi-Fi/background/process loss while Pi assistance continues.
- [ ] Verify Pi reboot/service restart/address change and bounded reconnect.
- [ ] Verify WAN-disabled operation and credential revocation.
- [ ] Record real NCNN latency/FPS, memory, temperature, throttling, and power.

## Release-Key Preservation

The ignored local keystore and properties file are not distribution artifacts.
Store an encrypted backup separately from the source workspace. Never commit or
share their passwords. Losing this signing identity prevents updates to an
installed build under the same application ID.
