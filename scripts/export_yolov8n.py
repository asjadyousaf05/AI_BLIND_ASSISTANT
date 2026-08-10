#!/usr/bin/env python3
"""Reproducibly prepare the official YOLOv8n COCO LiteRT model.

The script downloads only from the official ``ultralytics/assets`` release,
verifies the pinned SHA-256, exports a fixed 320 x 320 FP32-boundary LiteRT
model, validates its real tensors with the LiteRT interpreter, and installs
the model, labels, and generated metadata in ``mobile_app/assets/models``.

Ultralytics' current LiteRT exporter does not create a separate FP16 model.
Its FP32 model can use FP16 internally when a supported delegate is enabled.
This project intentionally starts with the verified CPU-compatible FP32 model
and does not claim INT8 quantization without a representative calibration set.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import shutil
import sys
import urllib.request
from pathlib import Path

import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEIGHTS = PROJECT_ROOT / "yolov8n.pt"
ASSET_DIR = PROJECT_ROOT / "mobile_app" / "assets" / "models"
MODEL_DESTINATION = ASSET_DIR / "yolov8n_float32.tflite"
LABELS_DESTINATION = ASSET_DIR / "coco_labels.txt"
METADATA_DESTINATION = ASSET_DIR / "model_metadata.json"

ULTRALYTICS_VERSION = "8.4.106"
LITERT_TORCH_VERSION = "0.9.3"
AI_EDGE_LITERT_VERSION = "2.1.6"
NUMPY_VERSION = "2.5.1"
MODEL_RELEASE = "v8.4.0"
MODEL_URL = (
    "https://github.com/ultralytics/assets/releases/download/"
    f"{MODEL_RELEASE}/yolov8n.pt"
)
MODEL_SHA256 = "f59b3d833e2ff32e194b5bb8e08d211dc7c5bdf144b90d2c8412c47ccfc83b36"
INPUT_SIZE = 320


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def acquire_weights(path: Path, refresh: bool) -> None:
    if refresh or not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        partial = path.with_suffix(path.suffix + ".download")
        print(f"Downloading official weights from {MODEL_URL}")
        urllib.request.urlretrieve(MODEL_URL, partial)
        if sha256(partial) != MODEL_SHA256:
            partial.unlink(missing_ok=True)
            raise RuntimeError("Downloaded weights failed the pinned SHA-256 check")
        partial.replace(path)

    actual = sha256(path)
    if actual != MODEL_SHA256:
        raise RuntimeError(
            f"Unexpected weights SHA-256 for {path}: {actual}; expected {MODEL_SHA256}"
        )
    print(f"Verified official weights: {path.name} ({actual})")


def lite_rt_interpreter(model_path: Path):
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError as exc:
        raise RuntimeError(
            "Install the pinned model export dependencies from "
            "scripts/model_export_requirements.txt"
        ) from exc
    return Interpreter(model_path=str(model_path))


def tensor_record(detail: dict) -> dict:
    quantization = detail.get("quantization", (0.0, 0))
    return {
        "name": str(detail.get("name", "")),
        "shape": [int(value) for value in detail["shape"]],
        "type": np.dtype(detail["dtype"]).name,
        "quantization_scale": float(quantization[0]),
        "quantization_zero_point": int(quantization[1]),
    }


def validate_model(model_path: Path) -> tuple[dict, dict]:
    interpreter = lite_rt_interpreter(model_path)
    interpreter.allocate_tensors()
    inputs = interpreter.get_input_details()
    outputs = interpreter.get_output_details()
    if len(inputs) != 1 or len(outputs) != 1:
        raise RuntimeError(
            f"Expected one input and one output, found {len(inputs)} and {len(outputs)}"
        )

    input_detail = inputs[0]
    output_detail = outputs[0]
    input_shape = [int(value) for value in input_detail["shape"]]
    output_shape = [int(value) for value in output_detail["shape"]]
    valid_input_shapes = (
        [1, 3, INPUT_SIZE, INPUT_SIZE],
        [1, INPUT_SIZE, INPUT_SIZE, 3],
    )
    if input_shape not in valid_input_shapes:
        raise RuntimeError(f"Unexpected input shape: {input_shape}")
    if len(output_shape) != 3 or 84 not in output_shape or 2100 not in output_shape:
        raise RuntimeError(f"Unexpected YOLO detection output shape: {output_shape}")
    if np.dtype(input_detail["dtype"]) != np.dtype(np.float32):
        raise RuntimeError(f"Expected float32 input, found {input_detail['dtype']}")
    if np.dtype(output_detail["dtype"]) != np.dtype(np.float32):
        raise RuntimeError(f"Expected float32 output, found {output_detail['dtype']}")

    # A real interpreter invocation catches unsupported operators and corrupt
    # assets. A zero image is sufficient for a tensor-contract warm-up check.
    input_tensor = np.zeros(input_shape, dtype=input_detail["dtype"])
    interpreter.set_tensor(input_detail["index"], input_tensor)
    interpreter.invoke()
    output_tensor = interpreter.get_tensor(output_detail["index"])
    if list(output_tensor.shape) != output_shape or not np.isfinite(output_tensor).all():
        raise RuntimeError("LiteRT warm-up returned an invalid output tensor")

    return tensor_record(input_detail), tensor_record(output_detail)


def export_model(weights: Path) -> None:
    try:
        import ultralytics
        from ultralytics import YOLO
    except ImportError as exc:
        raise RuntimeError(
            "Install the pinned model export dependencies from "
            "scripts/model_export_requirements.txt"
        ) from exc

    required_versions = {
        "ultralytics": ULTRALYTICS_VERSION,
        "litert-torch": LITERT_TORCH_VERSION,
        "ai-edge-litert": AI_EDGE_LITERT_VERSION,
        "numpy": NUMPY_VERSION,
    }
    actual_versions = {
        package: importlib.metadata.version(package) for package in required_versions
    }
    mismatches = {
        package: (required, actual_versions[package])
        for package, required in required_versions.items()
        if actual_versions[package] != required
    }
    if mismatches:
        raise RuntimeError(f"Model export dependency versions do not match: {mismatches}")

    model = YOLO(str(weights))
    if model.task != "detect" or len(model.names) != 80:
        raise RuntimeError("Weights are not the expected 80-class COCO detection model")
    # Keep the exported graph explicitly in inference mode. Ultralytics also
    # prepares a frozen export copy internally, but setting this before export
    # makes the intended batch-normalization/dropout behavior unambiguous.
    model.model.eval()
    if model.model.training:
        raise RuntimeError("The PyTorch model did not enter evaluation mode")

    print("Exporting YOLOv8n to LiteRT: imgsz=320, batch=1, FP32, NMS excluded")
    exported = Path(
        model.export(
            format="litert",
            imgsz=INPUT_SIZE,
            batch=1,
            device="cpu",
        )
    ).resolve()
    if not exported.is_file() or exported.suffix != ".tflite":
        raise RuntimeError(f"Ultralytics did not return a TFLite model: {exported}")

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(exported, MODEL_DESTINATION)
    if exported != MODEL_DESTINATION.resolve():
        exported.unlink(missing_ok=True)

    labels = [model.names[index] for index in range(len(model.names))]
    LABELS_DESTINATION.write_text("\n".join(labels) + "\n", encoding="utf-8")

    input_tensor, output_tensor = validate_model(MODEL_DESTINATION)
    metadata = {
        "model_name": "Ultralytics YOLOv8n",
        "task": "generic object detection",
        "weights_release": MODEL_RELEASE,
        "weights_source": MODEL_URL,
        "weights_sha256": MODEL_SHA256,
        "model_file": MODEL_DESTINATION.name,
        "model_sha256": sha256(MODEL_DESTINATION),
        "model_size_bytes": MODEL_DESTINATION.stat().st_size,
        "labels_file": LABELS_DESTINATION.name,
        "labels_sha256": sha256(LABELS_DESTINATION),
        "classes": len(labels),
        "label_order": "COCO 80-class order from the official weights",
        "exporter": f"ultralytics=={ULTRALYTICS_VERSION}",
        "export_dependencies": {
            package: f"{package}=={version}"
            for package, version in actual_versions.items()
        },
        "export_command": (
            "YOLO('yolov8n.pt').export(format='litert', imgsz=320, "
            "batch=1, device='cpu')"
        ),
        "format": "LiteRT .tflite",
        "precision": "FP32 input/output and weights",
        "fp16_note": (
            "The current Ultralytics LiteRT exporter does not emit a separate "
            "FP16 model. FP16 execution may be enabled later through a verified "
            "supported delegate; the app currently uses the CPU-safe FP32 path."
        ),
        "int8_quantized": False,
        "input_tensor": input_tensor,
        "output_tensor": output_tensor,
        "input_size": INPUT_SIZE,
        "input_color_order": "RGB",
        "normalization": "channel / 255.0 to [0, 1]",
        "resize": "aspect-ratio preserving letterbox with RGB 114 padding",
        "output_layout": "YOLOv8 cx,cy,w,h plus 80 class probabilities",
        "box_coordinates": "normalized_xywh_relative_to_letterboxed_input",
        "scores": "per-class probabilities; no softmax or extra sigmoid",
        "nms_in_model": False,
        "confidence_threshold_default": 0.45,
        "nms_iou_threshold": 0.45,
        "license": "AGPL-3.0 or Ultralytics Enterprise License",
        "license_url": "https://github.com/ultralytics/ultralytics/blob/main/LICENSE",
        "runtime_network_required": False,
    }
    METADATA_DESTINATION.write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )

    print(f"Installed model: {MODEL_DESTINATION}")
    print(f"Model SHA-256: {metadata['model_sha256']}")
    print(f"Input tensor: {input_tensor}")
    print(f"Output tensor: {output_tensor}")
    print("Validation warm-up: passed")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--weights",
        type=Path,
        default=DEFAULT_WEIGHTS,
        help="Destination/path for the pinned official yolov8n.pt weights",
    )
    parser.add_argument(
        "--refresh-weights",
        action="store_true",
        help="Re-download the pinned official weights before exporting",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    weights = args.weights.expanduser().resolve()
    try:
        acquire_weights(weights, args.refresh_weights)
        export_model(weights)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
