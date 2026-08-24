# Build and Run

Last reviewed: 2026-08-20

## Verified Project Environment

| Component | Verified value |
|---|---|
| Host | macOS arm64 |
| Flutter | 3.44.5 stable |
| Dart | 3.12.2 |
| Android compile/target SDK | Flutter default, currently 36 |
| Android min SDK | 24 |
| Java/Kotlin JVM target | 17 |
| State management and DI | Riverpod 3.4.2 |
| Camera | `camera` 0.12.0+2 / CameraX implementation |
| Native inference | LiteRT Android 2.1.5, non-transitive |
| TTS | `flutter_tts` 4.2.5 |
| Vibration | `vibration` 3.2.0 |
| App-control transcription | bundled Vosk English; dedicated Android recognizer preferred for manual voice |
| Assistant reasoning | optional Gemini; local Ollama `llama3.2:3b` fallback |

Use `--no-version-check` with Flutter commands on this host to avoid the known
Flutter startup/version-fetch delay.

## First-time macOS Setup

Install Flutter, Android Studio/SDK, a Java 17-compatible JDK, Android platform
and build-tools 36, platform tools, and the full NDK version requested by the
installed Flutter SDK. Accept Android SDK licenses:

```bash
flutter --no-version-check doctor -v
flutter --no-version-check doctor --android-licenses
```

Install the complete side-by-side NDK version requested by Flutter. This Mac's
partial NDK 28.2.13676358 was repaired with the matching official r28c
`llvm-objcopy`/`llvm-strip`, which is sufficient for the verified ARM64 build,
but a normal full SDK Manager installation is preferred on a new machine.

## Prepare the Bundled Model

The final model is already present in `mobile_app/assets/models/`. To reproduce
or replace it from the pinned official source:

```bash
cd AI_BLIND_ASSISTANT
python3 -m venv .venv
.venv/bin/python -m pip install -r scripts/model_export_requirements.txt
.venv/bin/python scripts/export_yolov8n.py --refresh-weights
```

The exporter validates the official weights hash, creates the fixed 320 x 320
LiteRT model, inspects and warms up its real tensors, and installs the model,
labels, and metadata. See [model-integration.md](model-integration.md).

## Resolve Flutter Dependencies

```bash
cd mobile_app
flutter --no-version-check pub get
```

After the packages are cached, dependency resolution is verified offline:

```bash
flutter --no-version-check pub get --offline
```

## Optional General-Conversation Backend

Hands-free, manual voice, and typed app controls need no backend, Ollama,
Gemini, internet, installed speech service, or laptop. Follow
[assistant.md](assistant.md) only to add general conversation.
The short form is:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/laptop_backend
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -e '.[dev]'
.venv/bin/python scripts/prepare_whisper_model.py --model base
ollama pull llama3.2:3b
ollama serve
```

In another terminal:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/laptop_backend
.venv/bin/python -m uvicorn src.ai_assistant.main:app \
  --host 0.0.0.0 --port 8765
```

On this Mac the same backend is already registered as the running per-user
launch service `com.ai-blind-assistant.backend`. The phone defaults to
`Asjads-MacBook-Pro.local:8765`; change host/port only for another laptop.
Secure one-time pairing remains required.

Gemini is optional. Put `GEMINI_API_KEY` or `GOOGLE_API_KEY` only in the ignored
backend `.env` or process environment, never Flutter. Gemini is tried first
when configured and Ollama handles failures automatically. With no key the
backend is fully local. Use port 8765 only on a trusted private LAN.

## Quality Checks

```bash
cd mobile_app
dart format --output=none --set-exit-if-changed lib test integration_test
flutter --no-version-check analyze
flutter --no-version-check test
```

Module 57 result: analyzer clean; 319 Flutter tests passed with code-free Pi
cross-process enrollment enabled; Pi Ruff and all 15 Pi tests passed; the app-native
Gradle unit task and split release build passed. The ARM64 release was installed
over the matching signed build on TECNO BG6 as version `1.4.2` / code `4042`.
The aggregate Gradle unit-test command still needs Java 21 for third-party
CameraX Robolectric tests under SDK 36; app-native tests pass under Java 17.
Physical Pi, phone-audio, voice and accessibility verification remains open.

## Raspberry Pi Local Connection

Wearable Mode is prefilled with `10.141.17.148` and service port `8765`.
Internet access is not required, but phone and Pi must be on one non-isolated
private LAN. Verify reachability before enrollment:

```bash
ping -c 3 10.141.17.148
nc -G 3 -zv 10.141.17.148 8765
```

On the Pi, start the matching service. The reviewed production environment has
`AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT=true`:

```bash
sudo systemctl restart ai-blind-assistant-pi.service
sudo systemctl status ai-blind-assistant-pi.service --no-pager
```

In the app, open Raspberry Pi Mode and tap `Connect & Start Detection`; a fresh
install automatically uses `10.141.17.148:8765`. Use `Use This Address` only if
the Pi's address changes. An unclaimed Pi enrolls this phone without a code,
the credential is saved through Android Keystore, and later connections remain
automatic. The app does not request or store an SSH password. Priority alerts
use the connected phone speaker, with Pi-local speech as the disconnect
fallback. If another active credential already exists, reset it locally with
`sudo -u aiba /opt/ai-blind-assistant/venv/bin/ai-blind-pi revoke all` before
retrying on an owner-controlled private LAN.

## Build Android ARM64 Debug APK

```bash
cd mobile_app
flutter --no-version-check build apk \
  --debug \
  --split-per-abi \
  --target-platform android-arm64
```

Verified output:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
```

Final SHA-256:
`bef7ec2b9762230264667fd7729034b0d4130ceec1fde4dadc9f083fe62707ce`.
The 698,923,608-byte debug size is caused by retained native debug
symbols; it is not a production size estimate.

The main manifest contains `INTERNET` and `ACCESS_NETWORK_STATE` for the local
Pi and paired assistant, plus `RECORD_AUDIO` for foreground hands-free/manual
voice. Mobile
object detection does not call a network API and no camera frame enters an
assistant/provider request.

## Connect a Physical Android Phone

1. On the phone, enable Developer options and USB or Wireless debugging.
2. For wireless setup, choose **Pair device with pairing code**, run
   `adb pair <ip:pair-port>`, enter the six-digit code, then use
   `adb connect <ip:debug-port>` if Android does not connect automatically.
3. Verify that the device is authorized:

```bash
adb devices -l
flutter --no-version-check devices
```

The device line must end with `device`, not `unauthorized` or `offline`.

Install the final signed release directly:

```bash
adb -s <android-device-id> install -r \
  deliverables/AI-Blind-Assistant.apk
```

Or launch from Flutter for debugging:

```bash
cd mobile_app
flutter --no-version-check run -d <android-device-id>
```

The exact command from this workspace is:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/mobile_app && \
flutter --no-version-check run -d <android-device-id>
```

## Physical-device Acceptance Checklist

- Grant, deny, and permanently deny camera permission; verify Open Settings.
- Confirm the rear preview is not stretched and boxes align in portrait and
  landscape.
- Point the camera at representative COCO objects and confirm detections are
  real, stable, and not mock data.
- Verify saved low/medium/high sensitivity changes detection filtering.
- Verify audio, vibration, and combined modes, cooldown, urgent interruption,
  and no continuous vibration.
- Disable Wi-Fi and mobile data or enable airplane mode, restart, and confirm
  assistance still enters Detecting.
- Background/resume and perform at least 20 rapid start/stop cycles without a
  crash or retained camera indicator.
- Run a sustained session while measuring inference time/FPS, memory, battery,
  and thermal state.
- Enable TalkBack and large text; verify logical focus, labels, live status, and
  stop/recovery controls.

Do not report these checks complete from emulator evidence.

## Latest Android Runtime Evidence

An ARM64 Android API 37 emulator (`emulator-5554`) was used on 2026-08-06:

- APK installation and launch passed;
- camera permission was granted;
- LiteRT loaded the bundled model and created the XNNPACK CPU delegate;
- the app reached Detecting with the virtual camera;
- stop/restart passed;
- background/resume settled in Paused and released the camera;
- a fresh process reached Detecting while Android airplane mode was enabled;
- no fatal Flutter/Android error was observed.

This does not verify real-camera box alignment, TTS/haptics, TalkBack, or
representative phone performance.

## Release Signing and Build

The repository contains a release-signing bootstrap that creates a local
project-specific RSA keystore and ignored `key.properties`. It never prints the
generated secret and refuses to overwrite an existing identity:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT
./scripts/configure_release_signing.sh
```

Run it only if the two ignored signing files do not already exist. Back up
`mobile_app/android/key.properties` and
`mobile_app/android/app/ai-blind-assistant-release.jks` securely; both are
required to publish future updates under the same signing identity.

Verified ARM64 release command:

```bash
flutter --no-version-check build apk \
  --release \
  --split-per-abi \
  --target-platform android-arm64
```

Do not add `--no-pub` to this release command after a debug/test dependency
refresh. Flutter must regenerate the release plugin registrant so the dev-only
`integration_test` plugin is excluded.

Module 57 result: passed. Current installed artifact:
`mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. It is
125,769,244 bytes with SHA-256
`a4ab50e4ef27c73104eec96c11854dbb088a5e407ecf175eb87d8abbf6a8717c`.
Its metadata is package `com.example.ai_blind_assistant`, version `1.4.2`,
ABI-adjusted split code `4042`, min SDK 24, and target SDK 36. The older
checksummed `deliverables/AI-Blind-Assistant.apk` is deliberately unchanged;
copy/rename the current candidate only through the release-delivery workflow.

## Troubleshooting

| Symptom | Resolution |
|---|---|
| `llvm-strip` cannot start | Install the complete Flutter-requested side-by-side NDK with Android SDK Manager, then rebuild. |
| Model load error | Rerun the exporter, confirm all three model assets exist, rebuild, and compare metadata/hash. |
| Camera permission permanently denied | Use the app's Open Settings action and enable Camera manually. |
| Camera permission is granted but startup fails | Install the current APK and read the displayed CameraX code. Close other camera apps, enable Android's global Camera access toggle, then Retry. The app tries every reported rear camera before failing. |
| Phone says no speech-recognition service is installed | Install `1.4.1` or newer. It bundles Vosk and needs no vendor speech service. Grant Microphone once, keep the app foregrounded/unlocked, and enable “Listen for Hey Vision AI”. |
| “Hey Vision AI” stops responding | Unlock and return the app to the foreground. Confirm Android's microphone indicator and the hands-free setting. Listening intentionally stops on lock/background and restarts on resume. |
| General conversation reports laptop unavailable | Start backend/Ollama, keep both devices on the same trusted private LAN, validate the private host and port 8765, then pair with a fresh code. App controls do not need this. |
| Gemini is unavailable | Check `/health` without printing a key. The request should use Ollama; verify Ollama and its model are running. |
| Release Java compilation references `integration_test` | Re-run the release command without `--no-pub` so Flutter regenerates the release-only plugin registrant. |
| Device is `unauthorized` | Unlock the phone and accept the USB debugging RSA prompt. |
| No Android target | Connect a physical ARM64 phone; emulator-only validation is insufficient for camera acceptance. |
| Flutter command stalls | Retry with `flutter --no-version-check`. |
| Future Kotlin warning from `flutter_tts` | Keep the verified version for now; upgrade and revalidate when the plugin supports built-in Kotlin. |
