# Pixel hotspot: restore the reflashed Pi and run detection

Date: 2026-10-22 (Asia/Karachi). Module 76 operational deployment.

## Result

Restored the actual Raspberry Pi 3B after the owner confirmed flashing a fresh OS.
The Pixel's existing 1.4.18 app discovers/enrolls/authenticates the Pi, synchronizes
settings and reaches Wearable assistance running. Actual telemetry shows Camera
Active, Detection model Ready and Assistance Running. Pi-side TCP confirms the
phone hotspot host is the direct client. The real camera processes frames with
zero service restarts. No application/Pi source changes, model switch, APK
replacement or cloud inference.

Final Pi check: active/running, enabled, NRestarts=0, processed count 1,710,
latest inference/frame age 520/581 ms. No phone TCP socket at that final instant;
pairing and owner-confirmed audio were verified during the foreground session.
Keep/reopen Wearable Mode for phone alerts; do not claim a persistent background
phone connection from earlier successful pairing.

The owner temporarily leaves/removes the app while using another application.
Android exit history reports USER REQUESTED / REMOVE TASK rather than a crash;
no relevant crash diagnostic is present. The Pi continues detecting locally. Do
not claim that phone audio remains connected while the owner closes its app.
The Pixel subsequently reconnects and again shows Wearable assistance running;
the Pi confirms a direct established phone socket. The owner explicitly confirms
**Test audio and object announcements both work**. This is actual bounded acoustic
acceptance, separate from the button activation and automated tests.

Important remaining gate: active undervoltage and throttling (`0x50005`), actual
ARM clock about 600 MHz. Selected live timing samples show inference 516–575 ms
and frame age 579–635 ms, with zero dropped-buffer counts at the sampled intervals.
These are interval samples, not percentiles or an accuracy evaluation. Stable
power and broader object accuracy/TalkBack acceptance remain separate from Running.

## Discovery, identity and privacy

Observed topology (DHCP values, not static defaults): Pixel hotspot
`10.34.116.134/24`, laptop `10.34.116.21`, Pi `10.34.116.190`. Pixel hotspot uses
2412 MHz (2.4 GHz). Laptop Wi-Fi identity matches the prior saved hotspot; no
hotspot password is read, copied or written by this work.

Initially the Pi is absent while the owner prepares/reflashes it. On its return,
SSH reports a changed key. The owner cannot inspect the console fingerprint but
explicitly confirms a fresh OS flash. Using the owner's private hotspot, pin the
fresh observed ED25519 identity for only rpi3-ml.local and its current address;
keep unrelated known-host entries and normal strict host checks. This is fresh
local trust after the reported reflash, not an out-of-band console fingerprint
verification. New OS identity requires new app enrollment; no old credential is
copied from TECNO or exposed from Pixel.

SSH and sudo passwords are entered only in hidden-answer local Mac dialogs and
passed transiently to SSH/sudo. No password/key/token is written into source,
documentation, tool arguments or output. No pairing verifier is read back. Camera
frames remain on the Pi; no image capture file, frame stream, audio recording,
cloud inference, provider test, shared API key or user-data clearing is introduced.
Filtered UI inspection uses a short-lived device XML file removed in finally;
no screenshot or full UI hierarchy is retained on the laptop.

## Restored installation

Fresh system: Raspberry Pi 3 Model B Rev 1.2, aarch64, Python 3.13.5, OV5647
camera detected. Picamera2/venv/Avahi already present, NCNN/service absent. Install
only missing espeak-ng and four dependencies; zero OS upgrades/removals. Through
the existing installer, restore:

- `/opt/ai-blind-assistant/service` and its system-site-packages venv.
- NCNN 1.0.20260526, websockets 15.0.1, zeroconf 0.151.5 and declared dependencies.
- The exact three finalized model files under `/opt/ai-blind-assistant/model`.
- Protected local service configuration, state/log directories and aiba identity
  with video/audio access, using the existing hardened systemd unit.
- Enabled `ai-blind-assistant-pi.service`, Avahi and the existing Wi-Fi-up
  dispatcher hook. Auto-select the current private interface; no static IP.
- The current Pi hotspot profile's auto-connect yes/priority 100, without exposing
  its password or changing the phone hotspot's credentials.

The service archive excludes virtual environments/caches/runtime state. Remote
staging remains at `/tmp/aiba-pixel-deploy-20261022` for recovery/audit and contains
only technical source/model/setup artifacts, no passwords or app credentials.
All 19 installed Python modules match workspace SHA-256 hashes. Reuse existing
320x240 camera capture, 8 camera FPS, four NCNN threads, 320x320 model input and
one-slot latest-frame processing. Camera FPS is not inference FPS. Keep existing
confidence/stability/cooldown/rate limits and authenticated strict protocol.

All model hashes match the existing manifest:

| File | SHA-256 |
|---|---|
| model.ncnn.param | `0f1fa584149ecfc61f8004c85b649b9b2b824b5058c1b8945282ea7654aee6ec` |
| model.ncnn.bin | `54ebc0872d04be072ad36c4cd3d668423e80365214b321db87b7c2547bfaa157` |
| metadata.yaml | `d159e757cd9423a9d6756a346badb915804a8ba3b63d53d2e05031b93845f161` |

Real validate-model succeeds: NCNN in0/out0, 320x320 input, actual [605,2100]
output, 601 Open Images V7 class entries. Artifact identity/metadata verification
is not evidence of new household fine-tuning or measured class accuracy.
The model is **Ultralytics YOLOv8n (Nano), Open Images V7, NCNN FP32**. Both the
installed manifest and the source artifact metadata identify this model; it runs
entirely on the Pi. This is distinct from Mobile Mode's COCO LiteRT artifact.

## Commands and exact verification

Commands run from the repository root unless specified. `<PI>` denotes the
current verified private hotspot endpoint; no password appears in commands.

| Command/check | Actual result |
|---|---|
| Laptop interface/default route, phone IPv4 interfaces and current SoftAP frequency | Laptop/Pi share Pixel hotspot; current topology above; 2.4 GHz |
| Bounded mDNS/SSH/TCP checks | Fresh Pi later resolves/replies; new SSH identity pinned after owner-confirmed reflash; SSH authenticated through local hidden dialog |
| `rpicam-hello --list-cameras` on Pi | Exit 0; OV5647 present, supported modes listed; no frames saved |
| Local SHA-256 manifest comparison and remote installer's `sha256sum -c` | All three model files match |
| `raspberry_pi/.venv/bin/python -m pytest -o addopts='' raspberry_pi/tests -q --disable-warnings` | Exit 0; **38 passed in 3.57 s** |
| `laptop_backend/.venv/bin/ruff check raspberry_pi/src raspberry_pi/tests` | Exit 0; All checks passed |
| `sh -n raspberry_pi/scripts/install.sh raspberry_pi/scripts/hotspot_network_dispatcher.sh raspberry_pi/scripts/deploy.sh` | Exit 0; no syntax errors |
| Bounded source/model tar + scp over the authenticated SSH control connection | Source 39,658 bytes; model 12,037,255 bytes; transferred/extracted successfully |
| Existing `scripts/install.sh --bind-host auto --model-source <STAGE>/model --start` under owner-authenticated sudo | Exit 0; service/runtime/models installed; no OS upgrade; five missing speech packages installed |
| `ai-blind-pi validate-model` under service identity/configuration | Exit 0; real NCNN shape [605,2100], 601 classes, expected blobs/input size |
| `systemctl show ... -p ActiveState -p SubState -p NRestarts -p UnitFileState` | active/running, enabled, NRestarts=0 through observed run |
| `ss -ltn '( sport = :8765 )'` | Actual listener on 10.34.116.190:8765 |
| Installed Python module hashes and package versions | 19/19 match; no mismatch; expected service/NCNN/websockets/zeroconf versions |
| `nmcli` current-profile auto-connect properties | yes, priority 100; no secret output |
| Pixel named Connect & Start control | First enrollment/auth/settings completed; UI reaches Wearable assistance running |
| Pixel live status panel | Assistance Running, Camera Active, Detection model Ready; undervoltage/throttling displayed honestly |
| Pi `ss -tn '( sport = :8765 )'` during foreground phone session | Direct established phone peer 10.34.116.134; no laptop relay or USB reverse tunnel |
| Pi aggregate journal timing | Real capture starts at 320x240; sampled processed counts grow through 1,260+, inference 516–575 ms, frame age 579–635 ms, sampled dropped=0 |
| Pixel named Test Phone Audio and physical object test | Control activated; owner confirms both test audio and real object announcements work |
| App exit-info / filtered crash diagnostics after owner leaves | Latest exit USER REQUESTED / REMOVE TASK; no relevant crash markers. Pi remains running; no phone socket after app removal |
| Subsequent Pixel reconnect | App again shows Wearable assistance running; Pi sees established direct phone peer, reusing saved trust |
| Android version/package | Existing 1.4.18/code 4058 retained; local-network permission granted; no rebuild/reinstall/data clear |
| Android formatting/analysis/build | Not rerun: no Android/Dart source changed; Module 75's verified artifact retained. Pi Ruff/tests/syntax and real deployment checks above are current evidence |
| Root `git diff --check`, source/Stitch baseline | Clean at validation; all application/Pi source and 31 Stitch hashes preserved against the 582-file pre-work baseline |

Minor diagnostic limitations: macOS ordinary hostname lookup intermittently misses
.local while DNS-SD/SSH IPv6 resolution finds the Pi; use the discovered current
IPv4 endpoint for deployment. `uiautomator dump /dev/tty` yields no usable XML on
this phone; short-lived filtered device-file inspection works. The old Android
`media` shell command is unavailable; no volume change is made. These do not
replace actual user audio acceptance or indicate a detection-service failure.

## Remaining power and acceptance checks

The Pi reports current under-voltage/throttling, not only historical flags. Actual
clock is around 600 MHz; observed temperature rises from 34.9 C idle to roughly
52 C under this run. Power quality needs correction before speed can be accepted.
Raspberry Pi's [official power guidance](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#power-supply)
recommends its 2.5 A micro-USB supply for Pi 3; supply/cable voltage loss matters.
Use a clean shutdown before changing the Pi supply, then remeasure under load.
Do not suppress the flags, overclock, lower detection safeguards or claim that
software tuning fixes a supply problem. ISSUE-076 remains open.

Owner confirms audible test and object announcements on Pixel. Current supply is
**laptop USB**, and a **5 V / 3 A mobile charger** is available. That charger has
not been connected or measured in this run; suitability depends on regulated
output and the cable. Do not claim that its rating alone clears the power fault.
Keep Wearable Mode visible for phone alerts. Removing/backgrounding the phone app
closes its link; the existing Pi-local assistance/fallback remains independent,
with actual Pi speaker audibility still a separate hardware check.

Exact next action: keep AI Blind Assistant > Wearable visible and use saved trust
if reconnecting. When the owner is ready, cleanly shut down before changing from
laptop USB to a suitable charger/cable, restart, and remeasure power/timing under
load before closing the performance gate. Current detection is left running;
no power swap or forced reboot is performed. No raw camera frame leaves the Pi.

## Required module record

1. Result: reflashed Pi restored; Pixel enrolled and Running/camera/model verified;
   Pi detection continues locally after owner removes the phone app.
2. Workspace before: dirty 582-file baseline; prior work preserved.
3. Architecture: existing local camera/inference, authenticated phone/Pi protocol.
4. State management: existing Riverpod unchanged.
5. Routing: existing named routes unchanged.
6. Folders created: none in source; existing standard Pi installation paths restored.
7. Screens created: none.
8. Domain types created: none.
9. Tests created: none; existing 38 Pi tests pass.
10. Markdown created: this deployment/verification report.
11. Markdown updated: current/status/handoff/changelog/index/issues/requirements/
    testing/hotspot guidance; final inventory below.
12. Requirements: FR-008/010/011/017/022, NFR-OFFLINE-001,
    NFR-SEC-002/004, NFR-MAINT-002, with limits in traceability.
13. Commands: discovery/strict SSH/secure sudo/model hashes/source transfer/
    installer/NCNN validation/systemd/nmcli/UI controls/TCP/timing/Pi tests/Ruff/
    shell syntax/diff; exact results above.
14. Results: 38 passes/3.57 s, clean Ruff/syntax; real NCNN/camera/phone Running,
    19/19 module hashes, zero restarts; owner accepts test/object audio.
15. Android build: not repeated, no app source change; verified installed 1.4.18 kept.
16. Files added: this report, with technical temporary deployment helpers outside
    the repository; no password files.
17. Files modified: living documentation plus the scoped local SSH known-host entry
    and fresh Pi service/runtime/model/network startup configuration.
18. Deliberately unchanged: all application/Pi source, models, protocols, providers,
    keys, source signing/version/dependencies, prior APKs and unrelated user work.
19. Stitch: 31 reference hashes preserved.
20. Known issues: active undervoltage/throttling, broader object/TalkBack checks,
    phone link closes when app is removed/backgrounded.
21. Deferred: power-qualified speed/accuracy/outage/boot matrix; no cloud/frame
    streaming, model replacement or new UI introduced.
22. Next action: keep Wearable visible, correct laptop-USB power after a clean
    shutdown when owner ready, remeasure under load.
23. Git-style summary: `ops(wearable): restore reflashed Pi and enroll Pixel`;
    no commit or push.

## Final repository inventory

One added file: `docs/PIXEL_PI_RESTORE_2026-10-22.md`.

Nine modified existing files: `docs/CURRENT_MODULE.md`, `docs/PROJECT_STATUS.md`,
`docs/AGENT_HANDOFF.md`, `docs/CHANGELOG.md`, `docs/INDEX.md`,
`docs/KNOWN_ISSUES.md`, `docs/TESTING.md`, `docs/requirements-traceability.md`,
`docs/PHONE_HOTSPOT.md`.

Against the 582-file pre-work SHA-256 baseline: no removed files, zero changed
mobile/backend/Pi source files, all 31 Stitch hashes unchanged. Root
`git diff --check` exits 0. Existing unrelated modifications/untracked files are
preserved. No commit or push. Runtime installation/configuration changes on the
Pi and scoped local SSH trust are described above; no password files created.
