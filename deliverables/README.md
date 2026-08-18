# AI Blind Assistant APK

`AI-Blind-Assistant.apk` is the locally signed ARM64-v8a release.

- Android 7.0 or newer (minimum API 24, target API 36)
- Package: `com.example.ai_blind_assistant`
- Version: `1.3.3` (ARM64 split build `2011`)
- Size: 97,185,174 bytes
- Core Mobile/Wearable assistance remains local and independent
- Typed app-control commands execute entirely on the phone without a backend or
  AI provider
- Foreground hands-free app controls listen for “Hey Vision AI” through the
  bundled Vosk English model and deterministic phone-local routing; no
  installed speech service, internet, or laptop is required
- The screen remains awake while the app is foregrounded. Listening pauses
  when the app is backgrounded or the phone is locked
- General conversation uses optional Gemini with automatic local Ollama
  fallback on the paired laptop

Verify and install on an authorized ARM64 Android phone:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/deliverables
shasum -a 256 -c AI-Blind-Assistant.apk.sha256
adb devices -l
adb -s <android-device-id> install -r AI-Blind-Assistant.apk
```

Grant Camera only for Mobile Mode and Microphone once for hands-free voice.
The laptop is optional and is needed only for general conversation. If paired,
it must be on a trusted private LAN. This assistive aid does
not replace a cane, guide dog, mobility training, human assistance, situational
awareness, or personal judgment.
