# AI Blind Assistant Mobile App

AI Blind Assistant is a native, Android-first Flutter assistive application:

- Mobile Mode uses CameraX, bundled YOLOv8n LiteRT, local TTS, and bounded
  vibration.
- Raspberry Pi Mode uses authenticated local discovery/control and Pi-local
  NCNN assistance.
- The in-app assistant supports typed input and explicit push-to-talk. App
  controls use Android's dedicated on-device speech recognizer and execute on
  the phone. A paired laptop is optional for general conversation: Gemini is
  preferred when configured and local Ollama is the automatic fallback.

The assistant can operate allow-listed settings and Mobile/Pi actions. Sensitive
actions require confirmation. Typed app-control commands are parsed and
executed entirely on the phone without pairing, internet, Gemini, or Ollama.
Spoken app controls use phone-local speech recognition and bypass both AI
providers. The assistant cannot run arbitrary code, access
camera frames, provide autonomous navigation, listen continuously, or control
Android outside this app.

## Run

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/mobile_app
flutter pub get
flutter run -d <android-device-id>
```

Start and pair the laptop service only for optional general conversation; see
`../docs/assistant.md`. Voice/typed app controls and Mobile Mode remain usable
without the laptop, Gemini, Ollama, or internet. Stitch files are
preserved design references and are not a WebView or runtime dependency.

See `../docs/BUILD_AND_RUN.md`, `../docs/assistant.md`,
`../docs/wearable-mode.md`, and `../docs/RELEASE_CHECKLIST.md`.
