# AI Blind Assistant Mobile App

AI Blind Assistant is an Android-first, offline assistive Flutter application
with two independent operating modes:

- Mobile Mode uses CameraX, a bundled 320 x 320 YOLOv8n COCO LiteRT model,
  local TTS, and bounded vibration feedback.
- Raspberry Pi Wearable Mode discovers or accepts a local Pi, pairs through a
  short-lived code, authenticates its WebSocket protocol, synchronizes settings,
  and controls the Pi-local NCNN assistance service.

The production interface is native Flutter. The preserved Stitch HTML and
rendered screenshots in `../stitch/` and `../docs/rendered-stitch/` are design
references, not WebView or runtime network dependencies.

## Run on macOS

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/mobile_app
flutter --no-version-check pub get
flutter --no-version-check run -d <android-device-id>
```

List an authorized device with `adb devices -l`. Core assistance has no cloud,
Firebase, analytics, account, camera upload, or runtime model download.

See `../docs/BUILD_AND_RUN.md`, `../docs/model-integration.md`,
`../docs/wearable-mode.md`, and `../docs/RELEASE_CHECKLIST.md` for the verified
build, model, Pi deployment, security, and physical acceptance procedures.
