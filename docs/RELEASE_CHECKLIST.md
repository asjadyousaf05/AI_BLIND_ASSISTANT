# Release Checklist

Last reviewed: 2026-08-20

Module 57 validation built split `1.4.2` release APKs and installed the ARM64
variant (split code `4042`) on the connected TECNO BG6. The immutable delivered
artifact table below still describes the separately checksummed `1.3.3` file in
`deliverables/`; it has not been silently replaced.

Current installed Module 57 candidate:

| Property | Verified value |
|---|---|
| Artifact | `mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Version | `1.4.2` (ABI-adjusted split code `4042`) |
| Size | 125,769,244 bytes |
| SHA-256 | `a4ab50e4ef27c73104eec96c11854dbb088a5e407ecf175eb87d8abbf6a8717c` |
| Device result | `adb install -r` succeeded; process alive/focused with no app-scoped fatal marker on TECNO BG6 |

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

- [x] Module 57 full Dart/Python formatting passed.
- [x] Flutter analyzer: clean, 0 findings.
- [x] Flutter suite: 319 passed; code-free cross-stack Pi process test enabled.
- [x] Pi Ruff clean; Pi pytest 15 passed with 46 upstream warnings.
- [x] Current native wake/grammar suite: 8 JVM tests passed.
- [x] Assistant widget, route, credential, controller, and large-text tests.
- [x] Backend Ruff: clean; pytest: 49 passed, 29 upstream warnings.
- [x] Gemini key precedence, text-only payload, structured parsing, and
      Gemini-to-Ollama fallback tests.
- [x] Live local Ollama structured response and retained optional-backend Whisper transcription.
- [x] Live backend startup/health/pair/authenticated-query/sensitivity tool.
- [x] ARM64 release build, alignment, signing, metadata, permissions, checksum.
- [x] Stitch sources preserved.
- [ ] Dedicated fresh Pi environment: dependency installation remains blocked;
      current Pi checks passed through the existing isolated laptop environment.
- [ ] Live Gemini: no Gemini key configured on this host.
- [x] Android USB install/update: TECNO BG6 Android 13/API 33, ARM64; app data
      preserved while updating the matching signed release to `1.4.2`.
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

- [x] Install `1.4.2`, launch, and verify a live focused process with no app-scoped fatal marker over USB.
- [ ] With the laptop unpaired and WAN off, type settings/Mobile/Pi commands;
      verify local parsing, confirmation, and truthful controller results.
- [ ] Deny/grant/permanently deny/revoke Microphone; verify Open Settings.
- [ ] Say “Hey Vision AI” and “Hi Vision AI”; verify “Listening.” once, then
      several focused-grammar commands without re-waking, timeout continuation,
      and “goodbye” restoration of wake-only state.
- [ ] Say “Open Smart AI”; verify continuous foreground questions use the same
      local Vosk input, local controls retain priority, and “bye” returns to the
      active offline command listener.
- [ ] In Document Scanner, issue semantic variants for scan/rescan,
      start/pause/resume/stop, previous/next/first/last/line 5, full-line spell,
      speed, copy, camera, and torch during one command session. Compare each
      with its matching visible control.
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
      one-wake/multiple-command/confirmation/background cycles; measure
      battery/thermal use.

## Physical Mobile and Raspberry Pi Gates

- [ ] Complete camera permission, real boxes, TTS/haptics, airplane-mode,
      lifecycle, TalkBack, orientation, persistence, performance, and thermal
      checks on the phone.
- [ ] Deploy Pi service; validate NCNN/hashes/601 labels; run two OV5647 sessions.
- [ ] Verify mDNS/manual endpoint, exclusive first-phone enrollment, second-phone rejection, control acknowledgements, detections,
      reconnect/reboot/IP-change, WAN-off behavior, and credential revocation.
- [ ] Verify connected-phone priority speech, no duplicate Pi speech, and
      Pi-local speech fallback after phone disconnect/background.
- [ ] Record phone/Pi latency, FPS, memory, battery/power, and temperature.

## Security and Release-Key Gates

- [x] Gemini/API tokens absent from source, APK, test fixtures, and docs.
- [x] Assistant bearer stored through Android Keystore AES-GCM.
- [x] Camera frames never enter assistant requests; Gemini gets text only.
- [x] Conversation-body retention is off by default.
- [x] Pi login credentials and SSH implementation are absent from the app;
      code-free enrollment issues a random Keystore-protected app credential.
- [ ] Perform first Pi enrollment on an owner-controlled isolated LAN and
      physically verify second-phone rejection plus local revoke-all recovery.
- [ ] Keep assistant port 8765 on a trusted private LAN; never port-forward.
- [ ] Add managed/pinned TLS before any hostile/untrusted-network use.
- [ ] Back up ignored `key.properties` and release keystore securely. Never
      print, commit, or distribute their secrets.

Do not call this safety-critical product fully accepted until every applicable
unchecked physical gate has measured evidence.
