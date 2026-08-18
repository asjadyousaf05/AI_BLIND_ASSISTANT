# Release Checklist

Last reviewed: 2026-08-14

## Delivered Build

| Property | Verified value |
|---|---|
| Artifact | `deliverables/AI-Blind-Assistant.apk` |
| ABI | ARM64-v8a |
| Package | `com.example.ai_blind_assistant` |
| Version | `1.3.3` (split code `2011`) |
| Android SDK | minimum 24; target 36 |
| Signing | one local RSA-3072 signer; APK Signature Scheme v2 |
| Size | 97,185,174 bytes |
| SHA-256 | `9430d92b35dca391b24b29521a30e1c294c0578498fa3619869827185713c8ae` |
| Permissions | Camera, Record Audio, Vibration, Network State, Internet; no storage/foreground service |

The APK passed metadata inspection, zipalignment, signature verification, and
checksum comparison. Microphone use is bounded to foreground hands-free/manual
voice; lock/background stops recognition.

## Automated Gates

- [x] Dart format: 179 files, zero changes.
- [x] Flutter analyzer: no issues.
- [x] Flutter suite: 202 passed; one Pi process test environment-gated/skipped.
- [x] Native wake matcher: 5 JVM tests passed.
- [x] Assistant widget, route, credential, controller, and large-text tests.
- [x] Backend Ruff: clean; pytest: 49 passed, 29 upstream warnings.
- [x] Gemini key precedence, text-only payload, structured parsing, and
      Gemini-to-Ollama fallback tests.
- [x] Live local Ollama structured response and retained optional-backend Whisper transcription.
- [x] Live backend startup/health/pair/authenticated-query/sensitivity tool.
- [x] ARM64 release build, alignment, signing, metadata, permissions, checksum.
- [x] Stitch sources preserved.
- [ ] Fresh Pi suite: blocked by PyPI DNS during environment creation.
- [ ] Live Gemini: no Gemini key configured on this host.
- [x] Android USB install/update: TECNO BG6 Android 13/API 33, ARM64; existing
      existing data preserved while updating to `1.3.3`.
- [x] Installed foreground app owns one active, unsilenced 16 kHz local
      `VOICE_RECOGNITION` client; missing vendor speech service no longer blocks it.
- [x] Physical cold launch and basic Mobile smoke: 709/591 ms starts, live
      preview, detection/alert, camera cleanup, and no app-scoped fatal crash.
- [ ] Wireless ADB pairing: connect service advertised, TLS pairing incomplete.

## Install and Launch

```bash
cd /Users/mm/AI_BLIND_ASSISTANT
shasum -a 256 -c deliverables/AI-Blind-Assistant.apk.sha256
adb devices -l
adb -s <android-device-id> install -r deliverables/AI-Blind-Assistant.apk
adb -s <android-device-id> shell monkey \
  -p com.example.ai_blind_assistant -c android.intent.category.LAUNCHER 1
```

## Physical Assistant Gates

- [x] Install `1.3.3`, launch, verify live process and active local listener over USB.
- [ ] With the laptop unpaired and WAN off, type settings/Mobile/Pi commands;
      verify local parsing, confirmation, and truthful controller results.
- [ ] Deny/grant/permanently deny/revoke Microphone; verify Open Settings.
- [ ] Say “Hey Vision AI”; verify spoken acknowledgement, then a separate
      full-vocabulary command, timeout recovery, and return to ready state.
- [ ] Say `what can you do`; verify the offline conversational spoken reply.
- [ ] Test `reduce sensitivity` then spoken `confirm`/`cancel`; verify no touch
      is required and no action runs before confirmation.
- [ ] Test manual tap/hold/release; verify transcript, stop, cancellation,
      background cleanup, and no laptop/backend dependency.
- [ ] With TalkBack, verify focus order, labels, live status, transcript,
      Confirm/Cancel, errors, and 2x text without clipping.
- [ ] Verify typed and spoken sensitivity, feedback/accessibility/cooldown,
      Mobile lifecycle, and Pi lifecycle/status commands.
- [ ] Confirm sensitive actions never execute before confirmation and that
      failures report the observed real state.
- [ ] Run Ollama-only with WAN off; then configure an owner Gemini key and prove
      Gemini success plus forced Gemini failure to Ollama fallback.
- [ ] Disable the backend/Wi-Fi during recognition and app-control processing;
      verify commands remain local, recovery is safe, and no microphone remains active.
- [ ] Check TTS/audio focus, `[unk]` rejection, false wakes, intended
      accent/noise, and 20 repeated
      wake/command/confirmation/background cycles; measure battery/thermal use.

## Physical Mobile and Raspberry Pi Gates

- [ ] Complete camera permission, real boxes, TTS/haptics, airplane-mode,
      lifecycle, TalkBack, orientation, persistence, performance, and thermal
      checks on the phone.
- [ ] Deploy Pi service; validate NCNN/hashes/601 labels; run two OV5647 sessions.
- [ ] Verify mDNS/manual endpoint, pairing, control acknowledgements, detections,
      reconnect/reboot/IP-change, WAN-off behavior, and credential revocation.
- [ ] Record phone/Pi latency, FPS, memory, battery/power, and temperature.

## Security and Release-Key Gates

- [x] Gemini/API tokens absent from source, APK, test fixtures, and docs.
- [x] Assistant bearer stored through Android Keystore AES-GCM.
- [x] Camera frames never enter assistant requests; Gemini gets text only.
- [x] Conversation-body retention is off by default.
- [ ] Keep assistant port 8765 on a trusted private LAN; never port-forward.
- [ ] Add managed/pinned TLS before any hostile/untrusted-network use.
- [ ] Back up ignored `key.properties` and release keystore securely. Never
      print, commit, or distribute their secrets.

Do not call this safety-critical product fully accepted until every applicable
unchecked physical gate has measured evidence.
