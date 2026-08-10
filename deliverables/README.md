# AI Blind Assistant APK

`AI-Blind-Assistant.apk` is the final locally signed ARM64-v8a Android release.

- Android 7.0 or newer (minimum API 24)
- Package: `com.example.ai_blind_assistant`
- Version: `1.0.1`
- Core Mobile Mode works offline; Wearable Mode uses only the local Pi network

Verify the checksum:

```bash
cd /Users/mm/AI_BLIND_ASSISTANT/deliverables
shasum -a 256 -c AI-Blind-Assistant.apk.sha256
```

Install on one authorized ARM64 Android phone:

```bash
adb devices -l
adb -s <android-device-id> install -r AI-Blind-Assistant.apk
```

Open **AI Blind Assistant** from the launcher. Grant Camera only when starting
Mobile Mode. This software is an assistive aid and does not replace a cane,
guide dog, mobility training, human assistance, or personal judgment.
