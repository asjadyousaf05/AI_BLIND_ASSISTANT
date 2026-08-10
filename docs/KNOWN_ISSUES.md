# Known Issues

Last reviewed: 2026-08-09

| ID | Severity | Issue | Current evidence/workaround | Status |
|---|---|---|---|---|
| ISSUE-003 | Medium | Workspace is not a Git repository. | Use explicit inventories and hashes; do not initialize Git without owner approval. | Open |
| ISSUE-004 | Low | Plain Flutter commands can stall in version/network checks. | Use `flutter --no-version-check ...`; use `--no-pub` after dependencies resolve. | Open |
| ISSUE-005 | Medium | `integration_test/app_startup_test.dart` has no Android-device result in this pass. | With no Android target, `flutter test integration_test` selected the macOS SDK and was stopped; do not claim `IT-STARTUP-001` passed. | Open |
| ISSUE-006 | High | Stitch references contain remote assets and incomplete semantics. | Native production UI does not load them; Stitch files remain unchanged references. | Mitigated |
| ISSUE-008 | Medium | Physical TalkBack behavior is unverified. | Semantic/widget coverage passes; `MT-TALKBACK-001` remains required. | In Progress |
| ISSUE-009 | Medium | Physical large-text/orientation review is unverified. | Native layouts pass 2.0 text-scale tests; physical review remains. | In Progress |
| ISSUE-012 | Low | `flutter doctor -v` reports unrelated XAMPP scan permissions and incomplete Xcode. | Neither blocks Android debug builds. | Open |
| ISSUE-013 | High | No physical Android phone was connected. | ARM64 emulator logs are not equivalent to real camera/TTS/haptic/TalkBack evidence. | Open |
| ISSUE-014 | Medium | Flutter TFLite packages were unavailable in the original offline cache. | Existing Kotlin MethodChannel uses verified non-transitive LiteRT 2.1.5. | Resolved by design |
| ISSUE-018 | Low | Inference diagnostics are internal. | Controller exposes processed/dropped/timing counters; no user-facing debug panel was added. | Open |
| ISSUE-019 | Medium | The ARM64 API 37 emulator became offline after the smoke run. | Current logs captured CameraX, model/XNNPACK, and `Detecting`; sustained emulator claims were not made. | Open |
| ISSUE-020 | Medium | The repository initially failed analysis/build because `wearable_providers.dart` was missing. | Provider composition restored; all 146 tests and analyzer pass. | Fixed |
| ISSUE-021 | Medium | Android NDK 28.2.13676358 originally lacked `llvm-strip`. | The exact official r28c `llvm-objcopy`/`llvm-strip` tool was restored in the host SDK; signed ARM64 release build now passes. A normal complete side-by-side NDK install is still preferred on another Mac. | Resolved locally |
| ISSUE-022 | Low | `flutter_tts` applies the legacy Kotlin Gradle plugin. | Flutter 3.44 warns about future incompatibility; the current build passes. | Open |
| ISSUE-023 | High | Full Mobile Mode physical acceptance is pending. | Real boxes/feedback/offline/lifecycle/performance/thermal checks remain in `TESTING.md`. | Open |
| ISSUE-024 | Medium | LiteRT Android 2.1.6 conflicts under AGP 9. | Its AAR namespaces collide; keep verified non-transitive 2.1.5 until packaging is compatible. | Open upstream / mitigated |
| ISSUE-025 | Low | LiteRT FlatBuffer exports are not byte-for-byte deterministic. | Pin dependencies and source; validate tensors/parity and record the exact packaged hash. | Documented |
| ISSUE-026 | Low | `litert-torch` logs a training-mode warning during export even after `model.model.eval()`. | The script asserts evaluation mode; exported inference tensor `[1,84,2100]`, warm-up, finite boxes, and PyTorch/LiteRT parity pass. Treat future tensor/parity changes as failure. | Open upstream / mitigated |
| ISSUE-027 | Medium | Release manifest includes network permissions despite older Module 14 records saying otherwise. | Current permissions are required only by the separately present local-LAN wearable module. Mobile Mode has no network call or runtime download. Living docs now state this boundary. | Resolved documentation conflict |
| ISSUE-028 | High | Actual Raspberry Pi deployment is blocked by SSH authorization. | Final probe resolved `rpi3-ml.local` and reached TCP 22, but BatchMode authentication was denied. Authorize the Mac public key for `asjad`; never store a password. | Open |
| ISSUE-029 | High | OV5647 has a known intermittent CSI timeout and no two-session result in this pass. | Bounded service recovery and `camera_smoke_test.py` exist. Run two independent sessions on the Pi; do not claim a software hardware fix. | Open |
| ISSUE-030 | Medium | Raspberry Pi NCNN/aarch64 compatibility and real OIV7 inference are unverified. | Parser/model metadata and simulator pass on macOS; deploy and run `ai-blind-pi validate-model` plus live inference on Pi. | Open |
| ISSUE-031 | Medium | Wearable Mode physical Android acceptance is unavailable. | Cross-stack process E2E and semantic tests pass, but real NSD, Keystore persistence, TalkBack, Wi-Fi interruption, reboot, and WAN-disabled operation need a phone/Pi. | Open |
| ISSUE-032 | Medium | No vibration motor or GPIO driver was specified for the wearable. | UI reports Pi haptics unavailable and does not guess a pin/circuit. Mobile Mode vibration remains independent. | Open hardware scope |
| ISSUE-033 | Medium | Protocol v1 local WebSocket traffic is authenticated but not confidential. | HMAC, nonces, replay checks, private endpoint validation, and no TLS bypass are implemented. Pair only on a trusted LAN; never port-forward. | Accepted boundary (ADR-032) |
| ISSUE-034 | Low | The final shareable release is ARM64-only, not a universal/multi-ABI APK. | The target physical Android phone class is ARM64. Building all ABIs would require a complete multi-architecture NDK installation and would materially increase the artifact. | Accepted release scope (ADR-036) |
| ISSUE-035 | Low | `com.example.ai_blind_assistant` is a technically valid but generic application ID. | It is consistent across the existing app and signed APK. Changing it now would create a different installed application and require an owner-selected permanent reverse-domain identity. | Open product decision |

## Highest-priority Next Resolution

Authorize SSH, deploy to `rpi3-ml`, validate the NCNN model, and run the two
OV5647 sessions before the wearable physical matrix. Separately connect a
physical ARM64 Android phone for both Mobile and Wearable acceptance. Do not
close hardware issues from simulator/emulator evidence.
