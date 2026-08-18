# Performance Test Plan

Last updated: 2026-08-06

## Scope

This plan measures the final 320 x 320 YOLOv8n LiteRT Mobile Mode pipeline on a
normal physical Android phone. Emulator timing is not representative and must
not be reported as phone performance.

Record device model, SoC, Android version, build type, ambient conditions,
battery level, selected sensitivity/feedback mode, scene, and test duration
with every result.

## Implemented Protections

- Camera delivery is capped at one frame every 200 ms, approximately 5 FPS.
- Native and Dart busy guards permit one inference at a time.
- Busy frames are dropped, never queued.
- Native preprocessing/inference runs on a background executor.
- Direct tensor buffers are reused where practical.
- CPU/XNNPACK is the safe default; no unverified hardware delegate is enabled.
- Stop/pause/error releases camera, interpreter, TTS, and vibration resources.

## `MT-PERF-001`: Inference Latency and Effective FPS

1. Use a real scene with several COCO objects and medium sensitivity.
2. Cold-start assistance and measure time to Detecting and first processed
   output.
3. Run at least 120 seconds after warm-up.
4. Capture per-inference milliseconds from `InferenceController` diagnostics.
5. Report count, mean, median, p95, maximum, processed frames, dropped frames,
   and effective processed FPS.

Initial engineering target: maintain responsive preview and approximately 5
processed frames per second when the phone can sustain it. Do not hide frame
drops; they are the intentional backpressure mechanism. An academic acceptance
threshold must be justified from observed devices rather than assumed here.

## `MT-PERF-002`: Startup

Measure permission check, camera initialization, model load/warm-up, stream
start, and first processed output separately for:

- first launch after install;
- cold process launch with permission already granted;
- stop then restart in the same process.

Report actual values. A provisional usability goal is under ten seconds cold
and under five seconds warm, subject to device evidence.

## `MT-PERF-003`: Memory and Resource Stability

1. Capture baseline `dumpsys meminfo` or Android Studio profiler data.
2. Run Detecting for five minutes.
3. Stop and confirm the camera indicator clears.
4. Perform 20 start/stop cycles.
5. Repeat a five-minute session and stop.
6. Compare Java, native, graphics, and total PSS; inspect for unbounded growth.
7. Confirm no duplicate image streams, interpreters, executors, TTS sessions,
   or active vibration remains.

Do not impose an arbitrary pass number without a device baseline; pass requires
a stable plateau and resources returning close to their post-initialization
baseline.

## `MT-PERF-004`: Background/Resume

Repeat Detecting → Home → wait five seconds → return → explicit Resume at least
ten times. Confirm each background transition stops streaming, the UI reaches
Paused, no inference continues, no camera remains held, and each explicit
resume creates one working stream.

## `MT-PERF-005`: Thermal and Battery

Run at least 30 minutes with the screen/camera continuously active. Record:

- starting/ending battery percentage and whether charging;
- Android thermal status and any throttling events;
- inference mean/p95 in five-minute windows;
- processed FPS in five-minute windows;
- surface/device temperature if a consistent measurement method is available;
- user-noticeable preview or TTS degradation.

Report the observed battery rate and thermal curve; do not claim a universal
battery target from one phone.

## `MT-PERF-006`: Feedback Latency and Queue Control

Use audio mode, then combined mode. Record time from stable alert selection to
speech start. Confirm:

- one top alert per update;
- global interval at least 1.2 seconds unless a critical upgrade occurs;
- default per-class cooldown three seconds;
- higher-risk interruption works without overlapping queues;
- stop cancels speech and haptics immediately.

## `MT-PERF-007`: Haptic Bounds

Verify the actual phone executes:

- moderate: one 100 ms pulse;
- high: two 150 ms pulses with a 100 ms gap;
- critical: three 200 ms pulses with 100 ms gaps.

Low-risk alerts are currently suppressed. Confirm no pattern loops and the
device falls back safely when amplitude control is unavailable.

## Diagnostic Access

Diagnostics remain available through the injected controllers rather than a
production debug panel:

```dart
final assistance = ref.read(assistanceControllerProvider.notifier);
final inference = ref.read(inferenceControllerProvider.notifier);

final processed = assistance.diagnostics.processedFrames;
final dropped = assistance.diagnostics.droppedFrames;
final averageMs = inference.averageInferenceMs;
final lastMs = inference.lastInferenceTimeMs;
```

Adding a developer-only export/report surface later requires an explicit scope
decision and must never log image/frame content.

## Current Result

No physical-phone performance measurements exist as of 2026-08-06. The ARM64
emulator reached Detecting and survived lifecycle checks, but its timing/FPS is
deliberately not reported as representative evidence.

