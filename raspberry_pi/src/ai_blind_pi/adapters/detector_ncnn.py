"""YOLOv8 Open Images V7 NCNN inference and post-processing."""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path
from typing import Any

import numpy as np
import yaml

from ..models import BoundingBox, Detection, Frame
from .base import DetectorAdapter

INPUT_SIZE = 320
EXPECTED_CLASSES = 601
EXPECTED_CANDIDATES = 2100
INPUT_BLOB = "in0"
OUTPUT_BLOB = "out0"

HIGH_PRIORITY_CLASSES = frozenset(
    {
        "airplane",
        "ambulance",
        "bicycle",
        "boy",
        "bus",
        "car",
        "cattle",
        "chair",
        "door",
        "girl",
        "man",
        "motorcycle",
        "person",
        "stairs",
        "staircase",
        "traffic light",
        "train",
        "truck",
        "van",
        "vehicle",
        "wheelchair",
        "woman",
    }
)


class NcnnYoloDetector(DetectorAdapter):
    def __init__(self, model_dir: Path, *, num_threads: int = 3):
        self.model_dir = model_dir
        self.num_threads = num_threads
        self._net: Any = None
        self._labels: list[str] = []
        self._metadata: dict[str, Any] = {}
        self._runtime_output_shape: tuple[int, ...] | None = None
        self._canvas = np.full((INPUT_SIZE, INPUT_SIZE, 3), 114, dtype=np.uint8)
        self._tensor = np.empty((3, INPUT_SIZE, INPUT_SIZE), dtype=np.float32)

    @property
    def model_description(self) -> dict[str, object]:
        return {
            "runtime": "ncnn",
            "inputBlob": INPUT_BLOB,
            "outputBlob": OUTPUT_BLOB,
            "inputSize": [INPUT_SIZE, INPUT_SIZE],
            "outputShape": [4 + EXPECTED_CLASSES, EXPECTED_CANDIDATES],
            "runtimeOutputShape": list(self._runtime_output_shape or ()),
            "classCount": len(self._labels) or EXPECTED_CLASSES,
            "task": self._metadata.get("task", "detect"),
            "sourceVersion": self._metadata.get("version"),
            "license": self._metadata.get("license"),
        }

    def load(self) -> None:
        if self._net is not None:
            return
        param_path = self.model_dir / "model.ncnn.param"
        bin_path = self.model_dir / "model.ncnn.bin"
        metadata_path = self.model_dir / "metadata.yaml"
        missing = [
            str(path) for path in (param_path, bin_path, metadata_path) if not path.is_file()
        ]
        if missing:
            raise RuntimeError("model files are missing: " + ", ".join(missing))
        metadata = yaml.safe_load(metadata_path.read_text(encoding="utf-8"))
        if not isinstance(metadata, dict):
            raise RuntimeError("metadata.yaml must contain a mapping")
        names = metadata.get("names")
        if not isinstance(names, dict):
            raise RuntimeError("metadata.yaml names must be an indexed mapping")
        normalized_names = {int(key): str(value) for key, value in names.items()}
        if sorted(normalized_names) != list(range(EXPECTED_CLASSES)):
            raise RuntimeError(
                "model metadata must contain contiguous Open Images labels "
                f"0..{EXPECTED_CLASSES - 1}"
            )
        image_size = metadata.get("imgsz")
        if image_size not in ([INPUT_SIZE, INPUT_SIZE], INPUT_SIZE):
            raise RuntimeError(f"model metadata imgsz must be {INPUT_SIZE}x{INPUT_SIZE}")
        if metadata.get("task") != "detect" or bool(metadata.get("end2end", False)):
            raise RuntimeError("model must be a non-end-to-end detection export")
        try:
            import ncnn
        except ImportError as error:
            raise RuntimeError(
                "the ncnn Python binding is unavailable; install a compatible aarch64 ncnn binding"
            ) from error
        net = ncnn.Net()
        net.opt.num_threads = self.num_threads
        net.opt.use_vulkan_compute = False
        if net.load_param(str(param_path)) != 0:
            raise RuntimeError("NCNN failed to load model.ncnn.param")
        if net.load_model(str(bin_path)) != 0:
            raise RuntimeError("NCNN failed to load model.ncnn.bin")
        self._labels = [normalized_names[index] for index in range(EXPECTED_CLASSES)]
        self._metadata = metadata
        self._net = net
        try:
            self._tensor.fill(0)
            warm_output = np.squeeze(self._extract(self._tensor))
            expected = (4 + EXPECTED_CLASSES, EXPECTED_CANDIDATES)
            if warm_output.shape not in {expected, expected[::-1]}:
                raise RuntimeError(
                    f"unexpected NCNN output shape {tuple(warm_output.shape)}; expected {expected}"
                )
            self._runtime_output_shape = tuple(int(value) for value in warm_output.shape)
        except Exception:
            self._net = None
            self._runtime_output_shape = None
            raise

    def detect(
        self, frame: Frame, *, confidence_threshold: float, nms_threshold: float
    ) -> Sequence[Detection]:
        if self._net is None:
            raise RuntimeError("detector is not loaded")
        input_tensor, scale, pad_x, pad_y, source_width, source_height = self._preprocess(frame)
        output = self._extract(input_tensor)
        return self.parse_output(
            output,
            confidence_threshold=confidence_threshold,
            nms_threshold=nms_threshold,
            scale=scale,
            pad_x=pad_x,
            pad_y=pad_y,
            source_width=source_width,
            source_height=source_height,
        )

    def _preprocess(self, frame: Frame) -> tuple[np.ndarray, float, int, int, int, int]:
        source = np.asarray(frame.pixels)
        if source.ndim != 3 or source.shape[2] < 3:
            raise RuntimeError("detector requires an HxWx3 image")
        source = source[:, :, :3]
        if frame.color_space == "bgr":
            source = source[:, :, ::-1]
        elif frame.color_space != "rgb":
            raise RuntimeError(f"unsupported frame color space: {frame.color_space}")
        source_height, source_width = source.shape[:2]
        scale = min(INPUT_SIZE / source_width, INPUT_SIZE / source_height)
        resized_width = max(1, min(INPUT_SIZE, round(source_width * scale)))
        resized_height = max(1, min(INPUT_SIZE, round(source_height * scale)))
        pad_x = (INPUT_SIZE - resized_width) // 2
        pad_y = (INPUT_SIZE - resized_height) // 2
        x_indices = np.minimum(
            (np.arange(resized_width, dtype=np.float32) / scale).astype(np.int32),
            source_width - 1,
        )
        y_indices = np.minimum(
            (np.arange(resized_height, dtype=np.float32) / scale).astype(np.int32),
            source_height - 1,
        )
        self._canvas.fill(114)
        self._canvas[
            pad_y : pad_y + resized_height,
            pad_x : pad_x + resized_width,
        ] = source[y_indices[:, None], x_indices[None, :]]
        np.divide(
            np.moveaxis(self._canvas, 2, 0),
            255.0,
            out=self._tensor,
            casting="unsafe",
        )
        return self._tensor, scale, pad_x, pad_y, source_width, source_height

    def parse_output(
        self,
        output: np.ndarray,
        *,
        confidence_threshold: float,
        nms_threshold: float,
        scale: float,
        pad_x: int,
        pad_y: int,
        source_width: int,
        source_height: int,
    ) -> list[Detection]:
        output = np.squeeze(output)
        expected = (4 + EXPECTED_CLASSES, EXPECTED_CANDIDATES)
        if output.shape == expected[::-1]:
            output = output.T
        if output.shape != expected:
            raise RuntimeError(
                f"unexpected NCNN output shape {tuple(output.shape)}; expected {expected}"
            )
        scores = output[4:, :]
        class_ids = np.argmax(scores, axis=0)
        confidences = scores[class_ids, np.arange(EXPECTED_CANDIDATES)]
        selected = np.flatnonzero(confidences >= confidence_threshold)
        if selected.size == 0:
            return []
        # Cap pre-NMS work to protect Pi 3 latency under unusually noisy frames.
        if selected.size > 600:
            top = np.argpartition(confidences[selected], -600)[-600:]
            selected = selected[top]
        boxes = np.empty((selected.size, 4), dtype=np.float32)
        xywh = output[:4, selected].T
        boxes[:, 0] = (xywh[:, 0] - xywh[:, 2] / 2 - pad_x) / scale
        boxes[:, 1] = (xywh[:, 1] - xywh[:, 3] / 2 - pad_y) / scale
        boxes[:, 2] = (xywh[:, 0] + xywh[:, 2] / 2 - pad_x) / scale
        boxes[:, 3] = (xywh[:, 1] + xywh[:, 3] / 2 - pad_y) / scale
        boxes[:, [0, 2]] = np.clip(boxes[:, [0, 2]], 0, source_width)
        boxes[:, [1, 3]] = np.clip(boxes[:, [1, 3]], 0, source_height)
        valid = (boxes[:, 2] > boxes[:, 0]) & (boxes[:, 3] > boxes[:, 1])
        boxes = boxes[valid]
        selected = selected[valid]
        keep = self._class_aware_nms(
            boxes, confidences[selected], class_ids[selected], nms_threshold
        )
        detections: list[Detection] = []
        for index in keep[:100]:
            candidate = selected[index]
            class_id = int(class_ids[candidate])
            normalized = BoundingBox(
                x_min=float(boxes[index, 0] / source_width),
                y_min=float(boxes[index, 1] / source_height),
                x_max=float(boxes[index, 2] / source_width),
                y_max=float(boxes[index, 3] / source_height),
            )
            detections.append(
                self._make_detection(class_id, float(confidences[candidate]), normalized)
            )
        return detections

    def _extract(self, input_tensor: np.ndarray) -> np.ndarray:
        if self._net is None:
            raise RuntimeError("detector is not loaded")
        import ncnn

        # The current official Python API exposes Extractor as a normal object,
        # not a context manager. Thread configuration belongs to Net options.
        extractor = self._net.create_extractor()
        input_result = extractor.input(INPUT_BLOB, ncnn.Mat(input_tensor))
        if input_result != 0:
            raise RuntimeError(f"NCNN rejected input tensor ({input_result})")
        extract_result, output_mat = extractor.extract(OUTPUT_BLOB)
        if extract_result != 0:
            raise RuntimeError(f"NCNN inference failed ({extract_result})")
        return np.asarray(output_mat, dtype=np.float32)

    @staticmethod
    def _class_aware_nms(
        boxes: np.ndarray,
        scores: np.ndarray,
        class_ids: np.ndarray,
        threshold: float,
    ) -> list[int]:
        order = np.argsort(scores)[::-1]
        keep: list[int] = []
        while order.size:
            current = int(order[0])
            keep.append(current)
            if order.size == 1:
                break
            rest = order[1:]
            xx1 = np.maximum(boxes[current, 0], boxes[rest, 0])
            yy1 = np.maximum(boxes[current, 1], boxes[rest, 1])
            xx2 = np.minimum(boxes[current, 2], boxes[rest, 2])
            yy2 = np.minimum(boxes[current, 3], boxes[rest, 3])
            intersection = np.maximum(0, xx2 - xx1) * np.maximum(0, yy2 - yy1)
            area_current = (boxes[current, 2] - boxes[current, 0]) * (
                boxes[current, 3] - boxes[current, 1]
            )
            area_rest = (boxes[rest, 2] - boxes[rest, 0]) * (boxes[rest, 3] - boxes[rest, 1])
            union = np.maximum(area_current + area_rest - intersection, 1e-9)
            iou = intersection / union
            suppress = (class_ids[rest] == class_ids[current]) & (iou > threshold)
            order = rest[~suppress]
        return keep

    def _make_detection(self, class_id: int, confidence: float, box: BoundingBox) -> Detection:
        center = box.center_x
        direction = "left" if center < 0.36 else "right" if center > 0.64 else "center"
        class_name = self._labels[class_id]
        important = class_name.casefold() in HIGH_PRIORITY_CLASSES
        central_weight = 1.0 - min(1.0, abs(center - 0.5) * 2)
        risk_score = box.area * (1.0 + 0.5 * central_weight) + (0.18 if important else 0)
        priority = max(0, min(100, round(risk_score * 100)))
        relative_proximity = "very_close" if box.area >= 0.45 and direction == "center" else None
        alert_category = "mobility_hazard" if important else "object"
        return Detection(
            class_id=class_id,
            class_name=class_name,
            confidence=confidence,
            bounding_box=box,
            direction=direction,
            priority=priority,
            alert_category=alert_category,
            relative_proximity=relative_proximity,
        )

    def close(self) -> None:
        self._net = None
        self._runtime_output_shape = None
