import '../../domain/entities/detection_result.dart';
import '../../domain/entities/obstacle_alert.dart';
import '../../domain/enums/proximity_level.dart';
import '../../domain/enums/risk_level.dart';
import '../../domain/enums/screen_position.dart';
import '../../domain/services/risk_assessor.dart';

class ObstacleRiskAssessor implements RiskAssessor {
  @override
  List<ObstacleAlert> assess(List<DetectionResult> detections) {
    if (detections.isEmpty) return [];

    final alerts = <ObstacleAlert>[];
    final now = DateTime.now();

    for (final detection in detections) {
      final position = _classifyPosition(detection.boundingBox.centerX);
      final proximity = _estimateProximity(detection);
      final importance = _importanceScore(detection, position);
      final riskLevel = _computeRisk(position, proximity, importance);

      alerts.add(
        ObstacleAlert(
          detection: detection,
          position: position,
          proximity: proximity,
          riskLevel: riskLevel,
          timestamp: now,
          importanceScore: importance,
        ),
      );
    }

    // Sort by risk level descending, then by proximity urgency
    alerts.sort((a, b) {
      final riskCmp = b.riskLevel.priority.compareTo(a.riskLevel.priority);
      if (riskCmp != 0) return riskCmp;
      final importanceCmp = b.importanceScore.compareTo(a.importanceScore);
      if (importanceCmp != 0) return importanceCmp;
      return b.proximity.urgency.compareTo(a.proximity.urgency);
    });

    return alerts;
  }

  ScreenPosition _classifyPosition(double normalizedCenterX) {
    if (normalizedCenterX < 0.15) return ScreenPosition.left;
    if (normalizedCenterX < 0.35) return ScreenPosition.centerLeft;
    if (normalizedCenterX < 0.65) return ScreenPosition.center;
    if (normalizedCenterX < 0.85) return ScreenPosition.centerRight;
    return ScreenPosition.right;
  }

  ProximityLevel _estimateProximity(DetectionResult detection) {
    // Use bounding box area as a proxy for proximity.
    // Larger area in frame → closer object.
    final area = detection.normalizedArea;
    final height = detection.normalizedHeight;

    // Combine area and height for better estimation.
    // Bottom-of-frame objects with large area are closest.
    final bottomProximity = detection.boundingBox.bottom;
    final score = (area * 0.4) + (height * 0.3) + (bottomProximity * 0.3);

    if (score > 0.55) return ProximityLevel.veryNear;
    if (score > 0.35) return ProximityLevel.near;
    if (score > 0.18) return ProximityLevel.medium;
    return ProximityLevel.far;
  }

  RiskLevel _computeRisk(
    ScreenPosition position,
    ProximityLevel proximity,
    double importance,
  ) {
    if (position.isCenter &&
        proximity == ProximityLevel.veryNear &&
        importance >= 0.65) {
      return RiskLevel.critical;
    }

    if (position.isCenter &&
        proximity == ProximityLevel.near &&
        importance >= 0.50) {
      return RiskLevel.high;
    }

    if (proximity == ProximityLevel.veryNear) {
      return RiskLevel.high;
    }

    if (position.isCenter && proximity == ProximityLevel.medium) {
      return RiskLevel.moderate;
    }

    if (proximity == ProximityLevel.near || importance >= 0.58) {
      return RiskLevel.moderate;
    }

    return RiskLevel.low;
  }

  double _importanceScore(DetectionResult detection, ScreenPosition position) {
    final size = (detection.normalizedArea / 0.30).clamp(0.0, 1.0);
    final centrality = switch (position) {
      ScreenPosition.center => 1.0,
      ScreenPosition.centerLeft || ScreenPosition.centerRight => 0.75,
      ScreenPosition.left || ScreenPosition.right => 0.35,
    };
    final classPriority = _safetyClassPriority(detection.label);
    return (size * 0.45) + (centrality * 0.35) + (classPriority * 0.20);
  }

  double _safetyClassPriority(String label) {
    if (_highPriorityClasses.contains(label)) return 1.0;
    if (_obstacleClasses.contains(label)) return 0.75;
    return 0.40;
  }

  static const _highPriorityClasses = {
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'bus',
    'train',
    'truck',
  };

  static const _obstacleClasses = {
    'bench',
    'chair',
    'couch',
    'bed',
    'dining table',
    'toilet',
    'potted plant',
    'suitcase',
    'backpack',
    'door',
    'desk',
    'refrigerator',
    'microwave',
    'oven',
    'toaster',
    'sink',
  };
}
