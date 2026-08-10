# YOLOv8n LiteRT Integration

Last reviewed: 2026-08-06

## Purpose and Safety Boundary

Mobile Mode runs generic COCO object detection entirely on the Android device.
It does not identify people, perform face recognition, upload camera frames, or
estimate metric distance. Bounding-box size and location are visual risk
heuristics only. The app remains an assistive aid and does not replace a white
cane, guide dog, trained human assistance, orientation and mobility training,
or user judgment.

## Final Model Artifact

| Property | Verified value |
|---|---|
| Architecture | Ultralytics YOLOv8n detect model |
| Training data | COCO pretrained weights, 80 classes |
| Official release | Ultralytics assets `v8.4.0` |
| Official weights URL | `https://github.com/ultralytics/assets/releases/download/v8.4.0/yolov8n.pt` |
| Weights SHA-256 | `f59b3d833e2ff32e194b5bb8e08d211dc7c5bdf144b90d2c8412c47ccfc83b36` |
| App model | `mobile_app/assets/models/yolov8n_float32.tflite` |
| App model SHA-256 | `57a4e7d1aad385ed2d140d11da5406c1f0931d0696b1cc0dc73703051f545112` |
| App model size | 12,765,643 bytes |
| Labels | `mobile_app/assets/models/coco_labels.txt` |
| Labels SHA-256 | `bd17f1ee35d5f3c862a4894605855abbb9dda4b0621fdb0ac4c2c8c7bb7e730a` |
| Generated metadata | `mobile_app/assets/models/model_metadata.json` |
| Precision | FP32 tensor boundary and weights |
| Runtime network | None |

Only the official Ultralytics assets release is accepted by the export script.
The script verifies the pinned weights hash before export. Model files are
bundled through the existing `assets/models/` entry in `pubspec.yaml`; the app
does not contain a runtime downloader.

The selected runtime artifact is
`com.google.ai.edge.litert:litert:2.1.5`, with transitive Play AI-delivery and
lifecycle dependencies excluded. LiteRT 2.1.6 was evaluated but its published
`litert` and `litert-api` AARs use the same namespace, which AGP 9 rejects.

## License

Ultralytics publishes the software and model under AGPL-3.0, with an
Ultralytics Enterprise License offered as an alternative. The project must
preserve and review the applicable licensing obligations before distributing
an APK. This document is a technical record, not legal advice.

Official references:

- `https://github.com/ultralytics/ultralytics/blob/main/LICENSE`
- `https://docs.ultralytics.com/integrations/tflite/`
- `https://docs.ultralytics.com/modes/export/`

## Reproducible macOS Export

The exporter is `scripts/export_yolov8n.py`; its pinned environment is
`scripts/model_export_requirements.txt`.

```bash
cd AI_BLIND_ASSISTANT
python3 -m venv .venv
.venv/bin/python -m pip install -r scripts/model_export_requirements.txt
.venv/bin/python scripts/export_yolov8n.py --refresh-weights
```

The verified export environment was:

- Python 3.14.6
- `ultralytics==8.4.106`
- `litert-torch==0.9.3`
- `ai-edge-litert==2.1.6`
- `numpy==2.5.1`
- PyTorch 2.12.1

The effective Ultralytics call is:

```python
YOLO("yolov8n.pt").export(
    format="litert",
    imgsz=320,
    batch=1,
    device="cpu",
)
```

NMS is deliberately not embedded in the model. The current Ultralytics LiteRT
export path does not emit a separate FP16 artifact; therefore this integration
uses the verified CPU-compatible FP32 model. No INT8 claim is made because no
representative calibration dataset was supplied. A supported hardware delegate
may later use reduced precision internally only after device-specific testing.

The script downloads the pinned weights, exports in a temporary workspace,
inspects the real tensors with LiteRT, invokes a zero-input warm-up, regenerates
the COCO labels and metadata, copies final assets, and removes temporary export
files. Tool virtual environments, caches, root weights, and intermediate
exports are ignored by `.gitignore`.

The export configuration and tensor contract are reproducible. The LiteRT
converter can emit byte-different FlatBuffers across otherwise equivalent
runs, so always record the SHA-256 of the artifact actually packaged.

## Verified Tensor Contract

### Input

| Field | Value |
|---|---|
| Name | `serving_default_args_0` |
| Shape | `[1, 3, 320, 320]` |
| Layout | NCHW |
| Type | float32 |
| Color | RGB |
| Normalization | channel value divided by 255.0, range `[0, 1]` |
| Quantization | none; scale `0`, zero point `0` |

### Output

| Field | Value |
|---|---|
| Name | `serving_default_output_0_output` |
| Shape | `[1, 84, 2100]` |
| Type | float32 |
| Candidate values | normalized `cx, cy, width, height` plus 80 class probabilities |
| Label order | official COCO 80-class order; class 0 is `person` |
| Activation | probabilities are already activated; do not apply sigmoid or softmax |
| Embedded NMS | no |

Neither Kotlin nor Dart blindly assumes this contract. Kotlin reads the model's
input and output tensor metadata. Dart checks the native metadata against the
generated asset metadata before accepting the model. The parser supports both
feature-major `[1, 84, N]` and candidate-major `[1, N, 84]` layouts while still
rejecting inconsistent tensor lengths or class counts.

## Camera and Preprocessing Flow

1. Request camera permission; do not initialize assistance if it is absent.
2. Open the rear camera with audio disabled and stream YUV420 frames.
3. Limit delivered frames to one every 200 ms, approximately 5 FPS maximum.
4. Copy the three camera planes because the camera plugin may reuse their
   buffers after the callback.
5. Send plane bytes, row strides, pixel strides, dimensions, rotation, and
   front-camera mirror metadata across the existing method channel.
6. On the dedicated Android executor, sample stride-aware Y, U, and V values
   and convert them directly to RGB.
7. Apply sensor/device rotation and front-camera mirroring.
8. Preserve aspect ratio, letterbox to 320 x 320, and fill unused pixels with
   RGB 114.
9. Write normalized RGB into the model's actual NCHW float tensor.
10. Run LiteRT with two CPU threads and the runtime's safe XNNPACK CPU path.

The current production path does not enable GPU or NNAPI delegates. CPU is the
portable fallback. Delegate work is deferred until support, accuracy,
lifecycle, and fallback are verified on each intended device class.

## Post-processing

The native bridge returns the output tensor plus real tensor and letterbox
metadata. Dart then:

1. selects the highest class probability for each candidate;
2. applies sensitivity-controlled confidence filtering;
3. converts normalized `xywh` into corners;
4. removes letterbox padding and divides by the resize scale;
5. clamps and normalizes boxes to the correctly rotated preview dimensions;
6. applies per-class Non-Maximum Suppression at IoU 0.45;
7. requires spatially matching detections across two consecutive processed
   frames before feedback;
8. maps the final normalized boxes onto the aspect-correct camera preview.

Sensitivity thresholds are:

| Setting | Confidence threshold |
|---|---:|
| Low | 0.60 |
| Medium | 0.45 |
| High | 0.30 |

## Accessible Feedback

Stable detections are ranked using a documented relative-importance score:

- bounding-box size: 45%;
- centrality: 35%;
- safety-relevant COCO class weighting: 20%.

The highest useful detection can produce short phrases such as “Person ahead,”
“Chair on the left,” or “Car ahead.” Low-risk detections are suppressed. “Very
close” is reserved for the strongest documented visual heuristic; it is never
presented as metric distance.

The orchestrator enforces saved audio/vibration mode, a per-class cooldown, a
duplicate signature check, a global 1.2-second minimum announcement interval,
and urgent risk-upgrade interruption. Only the highest-priority alert is
handled per update. Every vibration pattern is finite, and stop/pause cancels
speech and vibration.

## Lifecycle and Failure States

The Riverpod `AssistanceController` owns this flow:

```text
permission -> camera initialization -> model load/warm-up -> ready
-> image stream -> inference -> post-processing -> feedback -> detecting
```

It exposes permission required, denied, permanently denied with Open Settings,
loading camera, loading model, ready, detecting, paused, model error, camera
error, inference error, and feedback error states. One inference may run at a
time; new frames are dropped rather than queued. Start/stop generation tokens
prevent late async work from reviving a stopped session.

Inactive, paused, detached, stopped, error, and disposal paths stop the image
stream and release the camera, interpreter/executor work, detection state,
TTS, and vibration. Resume does not silently restart assistance; the user must
explicitly resume it.

## Model Replacement or Fine-tuning

1. Train or fine-tune from an appropriately licensed Ultralytics model and
   retain dataset/license records.
2. Export with the same fixed input and without embedded NMS.
3. Inspect actual input/output metadata; never rename a model and assume the
   old contract.
4. Regenerate labels and `model_metadata.json` together.
5. If the class count or label order changes, update the parser assumptions,
   safety-class mapping, risk tests, and feedback vocabulary.
6. Run model warm-up, reference-image parity, all Flutter tests, analysis,
   Android build, and the physical-device acceptance checklist.
7. Replace the bundled asset only after recording its source, license, hash,
   tensor contract, validation evidence, and accuracy trade-offs.

Do not use INT8 unless a real representative calibration dataset is included
and the quantized input/output contract and accuracy are measured.

## Verified Evidence and Remaining Acceptance

Verified on 2026-08-06:

- export script completed and warm-up passed;
- final tensor metadata matches the app contract;
- the official Ultralytics bus reference image produced three `person`
  detections and one `bus` from both PyTorch and the final LiteRT model;
- ARM64 Android debug APK built, installed, and launched on an ARM64 emulator;
- emulator entered Detecting, stopped, restarted, paused on background, and
  released its camera without a fatal error;
- a fresh emulator process entered Detecting with Android airplane mode on;
- all 128 automated tests passed and static analysis reported no issues.

Still required on a physical Android phone:

- real rear-camera permission denial/permanent-denial behavior;
- real-scene box alignment across portrait/landscape and representative
  camera plane strides;
- speech intelligibility, cooldown, priority interruption, and finite haptics;
- real offline/airplane-mode session;
- measured inference latency/FPS, memory, battery, and thermal behavior;
- repeated rapid start/stop and background/resume soak testing;
- TalkBack and large-text manual validation.

