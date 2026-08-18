import '../entities/bounding_box.dart';
import '../entities/detection_result.dart';

/// Multi-Model Detection Fusion Service.
///
/// Merges, deduplicates, and fuses detections produced by multiple on-device
/// vision models (e.g., General YOLOv8n Detector + Household Domain Model)
/// using Weighted Box Fusion (WBF) and multi-model Non-Maximum Suppression.
class MultiModelFusionService {
  const MultiModelFusionService({this.iouThreshold = 0.50});

  final double iouThreshold;

  /// Fuses detections from multiple model outputs into a unified list.
  List<DetectionResult> fuse({
    required List<DetectionResult> primaryModelDetections,
    required List<DetectionResult> householdModelDetections,
  }) {
    if (primaryModelDetections.isEmpty && householdModelDetections.isEmpty) {
      return const [];
    }
    if (primaryModelDetections.isEmpty) return householdModelDetections;
    if (householdModelDetections.isEmpty) return primaryModelDetections;

    final combined = <DetectionResult>[
      ...primaryModelDetections,
      ...householdModelDetections,
    ];

    // Sort by confidence descending
    combined.sort((a, b) => b.confidence.compareTo(a.confidence));

    final suppressed = List.filled(combined.length, false);
    final fusedResults = <DetectionResult>[];

    for (int i = 0; i < combined.length; i++) {
      if (suppressed[i]) continue;

      final current = combined[i];
      final matchingIndices = <int>[i];

      // Find all overlapping detections with same or compatible label
      for (int j = i + 1; j < combined.length; j++) {
        if (suppressed[j]) continue;

        final other = combined[j];
        if (current.label.toLowerCase() == other.label.toLowerCase() ||
            _isCompatibleLabel(current.label, other.label)) {
          final iou = current.boundingBox.iou(other.boundingBox);
          if (iou >= iouThreshold) {
            suppressed[j] = true;
            matchingIndices.add(j);
          }
        }
      }

      // If multiple matching detections exist across models, perform Weighted Box Fusion
      if (matchingIndices.length > 1) {
        final fusedBox = _weightedBoxFusion(
          matchingIndices.map((idx) => combined[idx]).toList(growable: false),
        );
        final maxConfidence = matchingIndices
            .map((idx) => combined[idx].confidence)
            .reduce((a, b) => a > b ? a : b);

        fusedResults.add(
          DetectionResult(
            classId: current.classId,
            label: current.label,
            confidence: maxConfidence,
            boundingBox: fusedBox,
            frameTimestamp: current.frameTimestamp,
          ),
        );
      } else {
        fusedResults.add(current);
      }
    }

    return fusedResults;
  }

  /// Calculates the confidence-weighted average of matching bounding boxes.
  BoundingBox _weightedBoxFusion(List<DetectionResult> detections) {
    double totalWeight = 0.0;
    double weightedLeft = 0.0;
    double weightedTop = 0.0;
    double weightedRight = 0.0;
    double weightedBottom = 0.0;

    for (final det in detections) {
      final weight = det.confidence;
      totalWeight += weight;
      weightedLeft += det.boundingBox.left * weight;
      weightedTop += det.boundingBox.top * weight;
      weightedRight += det.boundingBox.right * weight;
      weightedBottom += det.boundingBox.bottom * weight;
    }

    if (totalWeight <= 0) return detections.first.boundingBox;

    return BoundingBox(
      left: (weightedLeft / totalWeight).clamp(0.0, 1.0),
      top: (weightedTop / totalWeight).clamp(0.0, 1.0),
      right: (weightedRight / totalWeight).clamp(0.0, 1.0),
      bottom: (weightedBottom / totalWeight).clamp(0.0, 1.0),
    );
  }

  bool _isCompatibleLabel(String a, String b) {
    final la = a.toLowerCase();
    final lb = b.toLowerCase();
    if (la == lb) return true;
    if ((la == 'chair' && lb == 'couch') || (la == 'couch' && lb == 'chair')) {
      return true;
    }
    if ((la == 'dining table' && lb == 'desk') ||
        (la == 'desk' && lb == 'dining table')) {
      return true;
    }
    if ((la == 'cup' && lb == 'bottle') || (la == 'bottle' && lb == 'cup')) {
      return true;
    }
    return false;
  }
}
