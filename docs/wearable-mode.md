# Raspberry Pi Wearable Mode

Last reviewed: 2026-08-20

## Implemented architecture

```text
Existing RaspberryPiScreen
  -> Riverpod WearableController (UI intent/lifecycle only)
  -> WearableRepository domain boundary
  -> one WebSocket repository/state machine
       -> Android NSD `_aiba-wearable._tcp`
       -> saved Keystore-backed endpoint
       -> validated private IP/hostname fallback
       -> bounded retry + heartbeat + typed protocol v1
  -> Raspberry Pi long-lived Python service
       -> exclusive enrollment/protected verifier store
       -> Picamera2 OV5647 capture
       -> one-slot latest-frame queue
       -> one loaded NCNN OIV7 detector at 320 × 320
       -> class-aware NMS and relative visual priority
       -> bounded phone-target priority feedback while authenticated
       -> bounded local espeak-ng fallback after phone disconnect
       -> compact detections/status/health; never camera frames
```

Mobile Mode has a separate camera, LiteRT model, state machine, and feedback
pipeline. A missing or disconnected Pi does not disable it. While Flutter has
an authenticated foreground connection, the Pi sends only bounded priority
alerts to the phone's single voice/TTS owner. Disconnecting or backgrounding
Flutter closes only the phone transport; it never sends Stop, so active Pi
assistance continues and Pi-local speech becomes the fallback.

## Directory structure

- `mobile_app/lib/domain/...wearable...`: protocol-independent entities and
  discovery, transport, credential, and repository interfaces.
- `mobile_app/lib/infrastructure/networking/`: strict codec, HMAC, retry,
  deduplication, settings resolver, WebSocket repository/transport, and Android
  platform adapters.
- `mobile_app/lib/app/wearable_controller.dart`: Riverpod UI/lifecycle intent.
- `mobile_app/lib/app/wearable_phone_feedback_service.dart`: adapter from
  authenticated priority events to the app's single voice/TTS owner.
- `mobile_app/lib/features/raspberry_pi/`: the preserved accessible screen.
- `raspberry_pi/src/ai_blind_pi/`: service, protocol, security, persistence,
  camera/model adapters, discovery, feedback, and CLI.
- `raspberry_pi/tests/`: protocol, replay, state, model-parser, recovery,
  deployment, and WebSocket tests.
- `raspberry_pi/systemd/`: hardened non-root service unit.

## Model and inference contract

The installer expects `model.ncnn.param`, `model.ncnn.bin`, and
`metadata.yaml` as one artifact set. `raspberry_pi/model/SHA256SUMS` contains
the approved hashes and is verified before installation.

- Model source: official Ultralytics `yolov8n-oiv7.pt` checkpoint documented
  in the [Open Images V7 pretrained model catalog](https://docs.ultralytics.com/datasets/detect/open-images-v7/).
- Exporter recorded in metadata: Ultralytics `8.4.106`, export date
  `2026-07-26`.
- License recorded in metadata: AGPL-3.0. Distribution/deployment must comply
  with the [official Ultralytics licensing terms](https://www.ultralytics.com/license).
- Runtime/export: NCNN FP32 (`quantize: null`); no INT8 claim. The Pi package
  pins the official `ncnn==1.0.20260526` Linux-aarch64 Python runtime. The format and
  precision options are documented by the [official NCNN export guide](https://docs.ultralytics.com/integrations/ncnn/).
  Runtime calls follow the current [official Tencent NCNN Python API](https://github.com/Tencent/ncnn#quick-start).
- Input: blob `in0`, RGB float32 NCHW `1×3×320×320`, normalized `[0,1]`,
  aspect-ratio-preserving RGB-114 letterbox.
- Output: blob `out0`, raw non-end-to-end YOLO head logically `1×605×2100`:
  four `xywh` rows plus 601 class scores and no objectness row.
- Labels: exact contiguous 0–600 mapping from `metadata.yaml`; never COCO.
- Defaults: confidence `0.45`, class-aware NMS IoU `0.45`, capture 12 FPS,
  frame stride 2, three NCNN threads. Tune only from physical measurements.
- Feedback requires two stable frames and uses one cooldown per Open Images
  class across directions. The default allows 12 normal announcements per
  minute and at most three additional urgent interruptions, so the hard rate
  remains finite even during changing hazards.

Model load performs one zero-input NCNN warm-up and rejects an unexpected
runtime output shape before assistance can start. The parser removes
letterbox padding, normalizes boxes, applies confidence and
class-aware NMS, and emits left/center/right plus a 0–100 relative-priority
score. `very_close` is used only for a large central box and is an uncalibrated
visual heuristic—not metres.

## Code-free enrollment, security, and reconnect

The Pi advertises mDNS identity and also supports remembered and manual local
endpoints. Flutter refreshes a remembered endpoint by device ID before a
connection/reconnection, so DHCP address changes do not require a hardcoded
phone address. Only one connection operation and one assistance pipeline may
run at once.

First enrollment is local and requires no displayed code:

1. The production Pi environment explicitly enables first-client enrollment.
2. Flutter connects to `/wearable/v1`, negotiates protocol 1, verifies the
   `exclusive_first_client_enrollment` capability, and submits only its random
   installation ID.
3. An unclaimed Pi atomically accepts exactly one phone and returns a random
   per-phone credential once. Android encrypts it with
   a non-exportable Keystore AES-GCM key; the Pi persists only a derived HMAC
   verifier in a mode-0600 atomic state file.
4. Later connections prove the credential against a fresh nonce, then HMAC
   every envelope. Timestamp, sequence, message-ID replay, payload, and command
   state checks are enforced.
5. Forget Trusted Phone first revokes the active Pi credential, waits for the
   signed acknowledgement, then removes Android secure storage.

The production UI is prefilled with `10.141.17.148:8765`; a fresh install can
tap `Connect & Start Detection` directly. Use the editable address only if the
Pi's DHCP address changes. First use enrolls,
authenticates, synchronizes settings, and starts detection in one action; later
sessions reuse the Keystore credential. The app does not SSH into the Pi,
request/embed a Pi password, or allow a manually entered IP to bypass protocol
authentication.

First enrollment is trust-on-first-use. Perform it only on an owner-controlled,
non-isolated private router/hotspot. If the phone credential is lost while the
Pi still trusts it, run `ai-blind-pi revoke all` locally on the Pi before
enrolling again. The Pi rejects a second phone while any trusted credential is
active.

Heartbeat loss triggers at most five reconnect attempts with exponential
backoff, a maximum delay, and jitter. A new attempt re-runs mDNS endpoint
refresh. Important commands use unique IDs, signed acknowledgements, timeouts,
bounded retry, and a Pi idempotency cache. Settings use revision, UTC time,
source priority, and source ID, and are persisted before acknowledgement.

The installed `AIBA_BIND_HOST=auto` mode selects a concrete private IPv4
interface at each service start; it never listens on `0.0.0.0`. A lightweight
monitor notices a DHCP/interface-address change, shuts down cleanly, and lets
the bounded systemd failure policy restart on the newly selected address. mDNS
then advertises the new endpoint and Flutter refreshes it by stable device ID.

Protocol v1 uses authenticated `ws://`, not TLS. HMAC provides peer
authentication, integrity, freshness, and replay protection, but not
confidentiality. Enroll/connect only on a trusted private LAN, bind the service
to the current private interface, do not port-forward TCP 8765, and do not expose it
on public Wi-Fi. No certificate-validation bypass or global network override is
present. See `wearable-protocol.md` for the exact schema/canonicalization.

## Raspberry Pi 3B installation

Do not train/export on the Pi and do not install PyTorch or Ultralytics. Debian
must provide Picamera2. The installer obtains the pinned official NCNN aarch64
wheel as a normal project dependency; for offline installation, include it in
the reviewed `--wheelhouse`. `espeak-ng` is mandatory while local speech is
enabled.

For Debian 13's CPython 3.13 aarch64 environment, the expected wheel is
`ncnn-1.0.20260526-cp313-cp313-manylinux_2_24_aarch64.manylinux_2_28_aarch64.whl`
with SHA-256
`cc2c8000e4c0cae3fccc3ed5661c170f0daa41cfff41910407c10a62e9e586fc`.

Copy the `raspberry_pi` directory and finalized model directory to the Pi. The
configured address is currently `10.141.17.148`; use it only after confirming
that it is still assigned and reachable from the same private LAN:

```sh
# Run on the Mac from the repository root after SSH key access is configured.
scp -r raspberry_pi <pi-user>@10.141.17.148:~/
scp -r /path/to/yolov8n-oiv7_ncnn_model <pi-user>@10.141.17.148:~/
ssh <pi-user>@10.141.17.148
```

Then run on the Pi:

```sh
cd ~/raspberry_pi
sudo apt update
sudo apt install python3-venv python3-picamera2 espeak-ng avahi-daemon
python3 -c 'import picamera2'
(cd "$HOME/yolov8n-oiv7_ncnn_model" && \
  sha256sum -c "$HOME/raspberry_pi/model/SHA256SUMS")
sudo ./scripts/install.sh \
  --bind-host auto \
  --model-source "$HOME/yolov8n-oiv7_ncnn_model"
sudo -u aiba /opt/ai-blind-assistant/venv/bin/python -c \
  'import ncnn; print("ncnn import passed")'
sudo systemctl start ai-blind-assistant-pi.service
```

The installer creates restricted system user `aiba`, `/opt` service/venv/model
directories, protected state/log/config directories, and a hardened systemd
unit. It backs up an existing service directory, virtual environment, config,
unit, and replaced model files with timestamps. Use `--wheelhouse DIR` for a
reviewed offline Python wheelhouse. Add `--start` only when the NCNN binding,
Picamera2, model, camera, and speech dependencies have been checked.

For a replacement/fine-tuned model, create a new reviewed checksum file and
pass `--model-checksums FILE`. The service will still reject wrong class
count/order, size, task, end-to-end layout, or missing files.

### Enroll and manage the service

```sh
sudo systemctl enable ai-blind-assistant-pi.service
sudo systemctl start ai-blind-assistant-pi.service
sudo systemctl stop ai-blind-assistant-pi.service
sudo systemctl restart ai-blind-assistant-pi.service
sudo systemctl status ai-blind-assistant-pi.service --no-pager
sudo journalctl -u ai-blind-assistant-pi.service -n 200 --no-pager
sudo tail -n 200 /var/log/ai-blind-assistant/wearable-service.log
sudo -u aiba /opt/ai-blind-assistant/venv/bin/ai-blind-pi status
sudo -u aiba /opt/ai-blind-assistant/venv/bin/ai-blind-pi revoke all
sudo -u aiba /opt/ai-blind-assistant/venv/bin/ai-blind-pi validate-model
```

`Restart=on-failure`, restart delay, and systemd start limits prevent an
unbounded crash loop. Application logs rotate at bounded size/count. The
service stops camera, frame/inference tasks, WebSockets, model, and speech on
SIGTERM or inference/camera terminal failure.

## Local simulated end-to-end test

On macOS, from the repository root:

```sh
cd raspberry_pi
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[test]'
.venv/bin/ruff check src tests scripts
.venv/bin/python -m pytest
cd ../mobile_app
AIBA_PI_PYTHON=../raspberry_pi/.venv/bin/python \
  flutter --no-version-check test test/features/wearable
```

The cross-stack test launches the real Python simulator, performs exclusive
code-free enrollment,
authentication, settings request, start, detection event, disconnect,
reconnect-to-running, pause, resume, stop, credential revocation, and local
forget. Simulator detections are test evidence for networking/state logic only,
not camera/model accuracy or performance.

## macOS Flutter and Android commands

```sh
cd mobile_app
flutter --no-version-check pub get
adb devices -l
flutter --no-version-check devices
flutter --no-version-check run -d <android-device-id>
```

After dependencies and the APK are already cached, offline commands are:

```sh
flutter --no-version-check pub get --offline
flutter --no-version-check run --no-pub -d <android-device-id>
```

For Android wireless debugging, enable it in Developer Options and use the two
addresses shown by Android:

```sh
adb pair <phone-address>:<pairing-port>
adb connect <phone-address>:<debug-port>
adb devices -l
flutter --no-version-check run -d <android-device-id>
```

ADB pairing is unrelated to wearable enrollment and no ADB code is stored.

## Required physical Pi checks

Run these on `rpi3-ml` after deployment. The camera test opens, captures, and
closes the OV5647 twice without saving frames:

```sh
sudo -u aiba /opt/ai-blind-assistant/venv/bin/ai-blind-pi validate-model
sudo -u aiba /opt/ai-blind-assistant/venv/bin/python \
  /opt/ai-blind-assistant/service/scripts/camera_smoke_test.py --frames 30
sudo systemctl restart ai-blind-assistant-pi.service
sudo journalctl -u ai-blind-assistant-pi.service -n 200 --no-pager
```

Then enroll a physical Android phone, test mDNS and `rpi3-ml.local`, start/pause/
resume/stop, background/resume, process recreation, Wi-Fi interruption, Pi
reboot, WAN-disabled local operation, missing model, invalid/revoked credential,
phone-target priority audio, Pi-speech disconnect fallback, and
TalkBack/high-contrast/large-text focus. Record mean/p95 NCNN latency, FPS,
memory, temperature, throttling, and sustained power only from the real Pi.

## Troubleshooting and limitations

- **No discovery:** verify phone/Pi share a non-isolated LAN, Avahi is active,
  and `_aiba-wearable._tcp` is visible. Use `rpi3-ml.local` or current private
  address as fallback. Same internet access is not sufficient if the access
  point isolates clients or assigns non-routed local subnets.
- **Authentication:** Forget Trusted Phone. If the Pi retained the old
  credential, run local `ai-blind-pi revoke all`, then use Connect & Start to
  enroll again. Check phone/Pi clocks when signed messages are reported stale.
- **Protocol mismatch:** install matching app and service versions; version 1
  intentionally refuses incompatible peers.
- **Camera timeout:** use `rpicam-hello --list-cameras` (or the OS-provided
  libcamera equivalent), reseat/check CSI cable and power, and inspect kernel
  logs. Recovery is bounded. Software does not fix an intermittent OV5647
  hardware/CSI fault.
- **Model:** verify the three hashes, permissions, 601 metadata labels,
  `in0`/`out0`, and a compatible aarch64 `ncnn` binding.
- **Service:** inspect systemd status, journal, and rotating application log;
  confirm the configured private bind address is currently assigned.
- **Power/heat:** Pi 3B has 1 GB RAM and limited CPU. A real wearable needs
  stable power and thermal evaluation; simulator speed is meaningless.
- **Haptics:** no vibration motor/GPIO driver was specified for this Pi. The UI
  reports wearable vibration as unavailable; Mobile Mode vibration remains
  independent. Add and physically validate a bounded motor driver before
  enabling Pi haptics.
- **Speech:** an authenticated foreground phone owns priority speech. The Pi
  requires `espeak-ng` for background/disconnect fallback. The protocol marks
  exactly one target so the phone and Pi do not duplicate the same alert.
- **Safety:** OIV7 detections can be wrong or missed. This is an aid, not a
  replacement for a cane, guide dog, mobility training, human assistance, or
  judgment. No monocular metric-distance claim is made.
