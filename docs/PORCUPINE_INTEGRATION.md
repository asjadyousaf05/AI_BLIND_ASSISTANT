Porcupine (Picovoice) Wake-word Integration

This project includes a safe stub and Flutter bridge for Porcupine at:

- Android stub: mobile_app/android/app/src/main/kotlin/com/example/ai_blind_assistant/PorcupineWakeHandler.kt
- Flutter bridge: mobile_app/lib/assistant/porcupine_bridge.dart

These are intentionally non-invasive placeholders so the project builds and tests without the proprietary SDK. To fully enable Porcupine wake-word detection perform the steps below.

1. Acquire Porcupine SDK and keyword
   - Create a Picovoice developer account and generate a keyword file for the phrase "hi vision ai" (or choose a variant).
   - Download the appropriate Android native libraries (AAR or .so) for your target ABIs (arm64-v8a, armeabi-v7a, x86_64 if needed).

2. Add the dependency
   - Place the native .so files under `mobile_app/android/app/src/main/jniLibs/<abi>/libpv_porcupine.so` (or use the AAR).
   - Add any required Maven/AAR dependency to the `mobile_app/android/app/build.gradle` according to Picovoice instructions.

3. Implement native binding in PorcupineWakeHandler.kt
   - Create a Porcupine engine instance, configure sensitivity, and register a callback that invokes:
     `channel.invokeMethod("onHandsFreeWake", null)`
     This re-uses the existing on-device hands-free pipeline (Vosk/Android recognizer) so your app will wake and listen as currently implemented.

4. Tune sensitivity and audio path
   - Start with a conservative sensitivity (e.g., 0.5) and test in your target environment.
   - Continue to use WebRTC AEC/NS/AGC in the Vosk session for best speech recognition quality immediately after wake.

5. Testing checklist
   - Build and install the APK to your test device.
   - Verify that when you say the wake phrase the app responds rapidly with haptic/audio cue then listens for the command.
   - Test edge cases: while TTS is speaking, in noisy environments, and with different accents.

6. Privacy and licensing
   - Porcupine is provided under Picovoice terms. Do not include commercial Porcupine models in public releases without confirming licensing for your use case.
   - The app's privacy rules still apply: raw audio and transcripts must not be sent externally unless the user explicitly switches to the Smart AI assistant and pairs with a backend.

If preferred, the project already supports a fully open-source wake+ASR pipeline via Vosk and the bundled hands-free model. Use the bridge to compare both approaches in real-world conditions.
