# Detection Pipeline

Last reviewed: 2026-08-06

## Implemented Flow

```text
Camera YUV420 planes
  -> native stride-aware YUV-to-RGB conversion
  -> rotation/mirror correction
  -> aspect-preserving 320 x 320 letterbox
  -> float32 NCHW RGB tensor normalized to [0, 1]
  -> LiteRT YOLOv8n on background executor
  -> actual [1, 84, 2100] tensor
  -> confidence filter and per-class NMS
  -> undo letterbox and normalize to preview
  -> two-frame spatial stability
  -> relative risk and accessible feedback
```

## Camera Boundary

`MobileCameraService` uses the existing `camera` package and tries each rear
camera reported by Android until one initializes. CameraX error codes and
bounded descriptions remain visible for recovery instead of being reduced to a
generic exception type. Audio
capture is disabled. Each delivered `CameraFrame` contains three separately
copied planes, row stride, pixel stride, image dimensions, timestamp, rotation,
and lens direction. The app does not concatenate planes and pretend the result
is NV21.

Delivery is throttled to one frame every 200 ms. The native inference bridge
also uses an atomic busy guard, and the Dart controller accepts only one
inference at a time. Frames arriving while busy are dropped, not queued.

## Native Preprocessing and Inference

`InferenceHandler.kt` owns a two-thread LiteRT interpreter and a single
background executor. Model load, warm-up, conversion, tensor creation, and
inference do not run on the Android UI thread. Buffers are direct and reused
where practical.

Preprocessing reads real YUV plane strides, applies orientation and mirror
correction, converts to RGB, letterboxes with RGB 114, and divides each channel
by 255. The final model input is NCHW `[1, 3, 320, 320]`, not NHWC.

Kotlin reads input/output tensor metadata and supports float or quantized
buffers, although the packaged model is float32. It returns tensor metadata,
letterbox scale/padding, rotated source size, and elapsed inference time with
the output. CPU/XNNPACK is the verified default; unsupported delegates are not
enabled.

## YOLO Decoding

The final output is float32 `[1, 84, 2100]`: normalized `cx, cy, width, height`
followed by 80 already-activated COCO class probabilities. No sigmoid or
softmax is applied. The parser also handles the equivalent candidate-major
layout when metadata reports it.

Post-processing:

- selects each candidate's best class;
- applies saved sensitivity: low 0.60, medium 0.45, high 0.30;
- removes invalid or degenerate boxes;
- removes letterbox padding and maps into the rotated source frame;
- clamps final coordinates to normalized `[0, 1]` preview space;
- applies per-class NMS with IoU 0.45;
- requires two consecutive spatial matches before alerting.

The overlay consumes the same corrected normalized boxes and renders over an
aspect-correct preview. Physical-device validation is still required for real
camera stride/orientation variants and box alignment.

## Types and Ownership

| Type/component | Responsibility |
|---|---|
| `CameraFrame` / `CameraPlane` | stride-aware transient camera data |
| `TfliteInferenceService` | asset validation and method-channel boundary |
| `InferenceHandler` | model lifecycle, preprocessing, warm-up, inference |
| `RawInferenceOutput` | tensor plus transform/timing metadata |
| `YoloPostProcessor` | decoding, confidence filter, NMS, coordinate mapping |
| `DetectionStabilizer` | multi-frame spatial confirmation |
| `ObstacleRiskAssessor` | position, visual proximity, relative importance |
| `AssistanceController` | permission, lifecycle, start/stop/error ownership |

No camera frames or image byte arrays are stored, logged, or uploaded.

See [model-integration.md](model-integration.md) for exact model provenance and
tensor metadata.
