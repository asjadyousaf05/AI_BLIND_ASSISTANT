# Model Evaluation

Last reviewed: 2026-08-06

## Decision

The integrated model is the official Ultralytics YOLOv8n COCO detect model,
exported to LiteRT at a fixed 320 x 320 input. YOLOv8n was selected as the
first working Mobile Mode model because its nano architecture is appropriate
for mobile CPU evaluation while still providing generic 80-class COCO output.

The packaged artifact is FP32. The evaluated Ultralytics LiteRT exporter does
not create a separate FP16 file, and CPU-safe FP32 is more reliable than
claiming an unverified delegate path. INT8 was not produced because no real
representative calibration dataset was provided.

## Verified Contract

| Property | Value |
|---|---|
| Input | float32 NCHW `[1, 3, 320, 320]`, RGB, divided by 255 |
| Resize | aspect-preserving letterbox, RGB 114 padding |
| Output | float32 `[1, 84, 2100]` |
| Candidate data | normalized `cx, cy, w, h` + 80 class probabilities |
| Activation | no additional sigmoid or softmax |
| NMS | external, per class, IoU 0.45 |
| Labels | official COCO order; `person` is generic class 0 |
| Model size | 12,765,643 bytes |
| Network at runtime | none |

The final model SHA-256 is
`57a4e7d1aad385ed2d140d11da5406c1f0931d0696b1cc0dc73703051f545112`.
Full provenance, export commands, license, preprocessing, replacement steps,
and device acceptance criteria are in
[model-integration.md](model-integration.md).

## Functional Parity Check

The final PyTorch weights and final LiteRT asset were run on the official
Ultralytics bus reference image at 320 input, confidence 0.25, and IoU 0.45.
Both produced three `person` detections and one `bus`. The LiteRT invocation
completed successfully with its XNNPACK CPU delegate.

This is an export/integration sanity check, not an accuracy benchmark.

## Limitations

- COCO does not reliably cover stairs, curbs, drop-offs, glass, small overhead
  hazards, or every mobility-relevant obstacle.
- 320 x 320 reduces small-object detail compared with larger inputs.
- Low light, blur, occlusion, unusual viewpoints, and domain shift can reduce
  detection quality.
- Bounding boxes do not provide reliable real-world distance or depth.
- Generic `person` detection is not face or identity recognition.
- Real Android phone accuracy, latency, thermal, and battery evaluation remains
  required.

