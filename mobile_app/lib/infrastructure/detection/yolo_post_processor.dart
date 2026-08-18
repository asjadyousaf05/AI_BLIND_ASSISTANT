import '../../domain/entities/bounding_box.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/raw_inference_output.dart';
import '../../domain/services/detection_post_processor.dart';

class YoloPostProcessor implements DetectionPostProcessor {
  YoloPostProcessor({required this.labels});

  final List<String> labels;

  static const int _bboxParams = 4; // cx, cy, w, h

  @override
  List<DetectionResult> process(
    RawInferenceOutput rawOutput, {
    double confidenceThreshold = 0.4,
    double iouThreshold = 0.45,
    Set<int>? allowedClassIds,
  }) {
    final data = rawOutput.data;
    if (rawOutput.outputShape.length != 3 || rawOutput.outputShape.first != 1) {
      return [];
    }
    final expectedFeatures = _bboxParams + labels.length;
    final featureMajor = rawOutput.outputShape[1] == expectedFeatures;
    final candidateMajor = rawOutput.outputShape[2] == expectedFeatures;
    if (!featureMajor && !candidateMajor) return [];

    final numCandidates = featureMajor
        ? rawOutput.outputShape[2]
        : rawOutput.outputShape[1];
    if (data.length != numCandidates * expectedFeatures) return [];

    double valueAt(int feature, int candidate) {
      return featureMajor
          ? data[feature * numCandidates + candidate]
          : data[candidate * expectedFeatures + feature];
    }

    // Derive whether features or candidates are the middle axis from the
    // interpreter-reported tensor shape. Both [1, 84, N] and [1, N, 84]
    // exports are supported; no candidate count is assumed.

    final candidates = <_Candidate>[];
    for (int i = 0; i < numCandidates; i++) {
      // Find best class score for this candidate
      double maxScore = 0;
      int bestClassId = 0;

      for (int c = 0; c < labels.length; c++) {
        final score = valueAt(_bboxParams + c, i);
        if (!score.isFinite) continue;
        if (score > maxScore) {
          maxScore = score;
          bestClassId = c;
        }
      }

      if (maxScore < confidenceThreshold) continue;
      if (allowedClassIds != null && !allowedClassIds.contains(bestClassId)) {
        continue;
      }

      var cx = valueAt(0, i);
      var cy = valueAt(1, i);
      var w = valueAt(2, i);
      var h = valueAt(3, i);
      if (![cx, cy, w, h].every((value) => value.isFinite)) continue;
      if (rawOutput.boxCoordinatesNormalized) {
        cx *= rawOutput.inputWidth;
        cy *= rawOutput.inputHeight;
        w *= rawOutput.inputWidth;
        h *= rawOutput.inputHeight;
      }

      final box = _modelBoxToPreview(rawOutput, cx, cy, w, h);
      if (!box.isValid) continue;

      candidates.add(
        _Candidate(classId: bestClassId, confidence: maxScore, box: box),
      );
    }

    // Sort by confidence descending for NMS
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Apply Non-Maximum Suppression per class
    final kept = _nms(candidates, iouThreshold);

    // Convert to DetectionResult
    return kept.map((c) {
      final label = c.classId < labels.length
          ? labels[c.classId]
          : 'class_${c.classId}';
      return DetectionResult(
        classId: c.classId,
        label: label,
        confidence: c.confidence,
        boundingBox: c.box,
        frameTimestamp: rawOutput.timestamp,
      );
    }).toList();
  }

  BoundingBox _modelBoxToPreview(
    RawInferenceOutput raw,
    double cx,
    double cy,
    double w,
    double h,
  ) {
    if (raw.letterboxScale <= 0 ||
        raw.effectivePreviewWidth <= 0 ||
        raw.effectivePreviewHeight <= 0) {
      return const BoundingBox(left: 0, top: 0, right: 0, bottom: 0);
    }
    final halfW = w / 2;
    final halfH = h / 2;
    final left =
        ((cx - halfW - raw.letterboxPaddingX) / raw.letterboxScale) /
        raw.effectivePreviewWidth;
    final top =
        ((cy - halfH - raw.letterboxPaddingY) / raw.letterboxScale) /
        raw.effectivePreviewHeight;
    final right =
        ((cx + halfW - raw.letterboxPaddingX) / raw.letterboxScale) /
        raw.effectivePreviewWidth;
    final bottom =
        ((cy + halfH - raw.letterboxPaddingY) / raw.letterboxScale) /
        raw.effectivePreviewHeight;
    return BoundingBox(
      left: left.clamp(0.0, 1.0),
      top: top.clamp(0.0, 1.0),
      right: right.clamp(0.0, 1.0),
      bottom: bottom.clamp(0.0, 1.0),
    );
  }

  List<_Candidate> _nms(List<_Candidate> candidates, double iouThreshold) {
    final suppressed = List.filled(candidates.length, false);
    final kept = <_Candidate>[];

    for (int i = 0; i < candidates.length; i++) {
      if (suppressed[i]) continue;
      kept.add(candidates[i]);

      for (int j = i + 1; j < candidates.length; j++) {
        if (suppressed[j]) continue;
        if (candidates[i].classId != candidates[j].classId) continue;
        if (candidates[i].box.iou(candidates[j].box) >= iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return kept;
  }
}

class _Candidate {
  const _Candidate({
    required this.classId,
    required this.confidence,
    required this.box,
  });

  final int classId;
  final double confidence;
  final BoundingBox box;
}
