# Finalized Raspberry Pi model

The production service expects these three files in `AIBA_MODEL_DIR`:

- `model.ncnn.param`
- `model.ncnn.bin`
- `metadata.yaml`

The binaries are deliberately not duplicated in this repository. Supply the
inspected finalized artifact directory explicitly to `scripts/install.sh` with
`--model-source`; runtime code contains no development-machine path.

Artifact metadata:

- Architecture: Ultralytics YOLOv8n detection model
- Dataset: Google Open Images V7
- Ultralytics exporter version: 8.4.106
- Export date recorded by metadata: 2026-07-26
- Runtime: NCNN, FP32 export (`quantize: null`)
- Pi Python runtime: official `ncnn==1.0.20260526` aarch64 wheel
- Input: `in0`, float32 RGB NCHW, `1x3x320x320`, values normalized to `[0,1]`
- Output: `out0`, raw YOLOv8 head, logically `1x605x2100`
- Output rows: 4 decoded `xywh` coordinates followed by 601 class probabilities; no objectness row
- NMS: not embedded (`end2end: false`), performed by the service
- Label order: the exact indexed `names` mapping in `metadata.yaml`; never substitute COCO labels
- License recorded by the artifact: Ultralytics AGPL-3.0, <https://ultralytics.com/license>

Audited SHA-256 hashes:

```text
model.ncnn.param  0f1fa584149ecfc61f8004c85b649b9b2b824b5058c1b8945282ea7654aee6ec
model.ncnn.bin    54ebc0872d04be072ad36c4cd3d668423e80365214b321db87b7c2547bfaa157
metadata.yaml     d159e757cd9423a9d6756a346badb915804a8ba3b63d53d2e05031b93845f161
```

Verify a copied model on the Pi:

```sh
sha256sum /opt/ai-blind-assistant/model/model.ncnn.{param,bin} \
  /opt/ai-blind-assistant/model/metadata.yaml
sudo -u aiba /opt/ai-blind-assistant/venv/bin/ai-blind-pi validate-model
```

`validate-model` loads the parameter/binary pair and performs one zero-input
warm-up, including a real `in0`/`out0` runtime-shape check.

Do not install PyTorch or Ultralytics on the Pi. Export or training belongs on a development machine; replace all three artifacts as one versioned set, validate their hashes and metadata, then restart the service.
