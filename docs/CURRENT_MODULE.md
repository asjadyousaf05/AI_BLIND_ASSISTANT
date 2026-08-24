# Current Module

Last updated: 2026-08-20

## Module

Module 57: Exclusive Code-Free Raspberry Pi Enrollment

## Result

Implemented and simulation/release verified; physical Pi deployment remains
blocked by the current network state.

1. Removed the Raspberry Pi pairing-code field and Pair Device action from the
   production Flutter UI. An unclaimed compatible Pi now uses one `Connect &
   Start Detection` action for enrollment, authentication, settings sync, and
   detection startup.
2. Added strict `enrollment_request` / `enrollment_result` protocol messages.
   Code-free enrollment must be explicitly enabled by the Pi deployment, is
   accepted only from a private/loopback peer, and closes after the first active
   phone credential.
3. Made first enrollment atomic. Concurrent first-phone attempts produce one
   credential and one `enrollment_closed` response.
4. Kept the random per-phone credential, Android Keystore AES-GCM storage,
   protected Pi verifier, nonce-bound HMAC authentication, signed envelopes,
   replay rejection, revocation, and bounded reconnect behavior.
5. The Linux login is not requested, stored, sent through the wearable
   protocol, or packaged in Android. No SSH dependency or password-based app
   connection was added.
6. Kept Module 56 phone-speaker detection feedback, Pi-local disconnect
   fallback, local-only camera/inference, and no-frame transport unchanged.
7. Added user-visible trust-on-first-use disclosure and recovery guidance. A
   lost offline phone credential requires local `ai-blind-pi revoke all` before
   another phone can enroll.
8. Bumped the release to `1.4.2+2042` and installed the signed ARM64 split on
   the connected TECNO BG6 as ABI-adjusted code `4042`.

## Verification

- Dart formatting: 226 files checked, 0 changed.
- Raspberry Pi Ruff: all checks passed.
- Full Flutter analyzer: clean, 0 findings.
- Full Flutter suite with real Python simulator: 319 passed, 0 failed.
- Raspberry Pi suite: 15 passed, 46 upstream Python 3.14 warnings, 0 failed.
- Android `:app:testDebugUnitTest`: `BUILD SUCCESSFUL`.
- Split release APK build: ARM 113.4 MB, ARM64 125.8 MB, x86_64 130.7 MB.
- ARM64 APK: 125,769,244 bytes; SHA-256
  `a4ab50e4ef27c73104eec96c11854dbb088a5e407ecf175eb87d8abbf6a8717c`.
- APK alignment and v2 signature: verified; one signer.
- `adb install -r`: `Success`; installed version `1.4.2`, code `4042`, min SDK
  24, target SDK 36. Launch request succeeded, the process remained alive and
  focused behind the sleeping/locked notification shade, and app-scoped fatal
  markers were absent.
- Release AOT/source scan: SSH implementation markers absent.

## Physical Blocker

The phone remains `10.141.10.93/21`. `10.141.17.148` again returned 100%
packet loss from the phone, while TCP 22 and 8765 timed out from the Mac. The
matching Module 57 Pi service therefore could not be deployed or physically
enrolled. Same internet/SSID is insufficient; both devices need one routed,
non-isolated private LAN.

## Exact Next Action

Power the Pi and connect it and the TECNO BG6 to the same owner-controlled
private router/hotspot. Confirm the Pi's current address, deploy the matching
Module 57 `raspberry_pi` service, ensure
`AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT=true`, start the service, and verify TCP
8765. In the app tap `Connect & Start Detection` once; edit the address first
only if DHCP assigned a different one.
Capture successful enrollment/authentication, running state, phone-speaker
priority alert, Pi disconnect fallback, camera/model logs, and TalkBack focus.
