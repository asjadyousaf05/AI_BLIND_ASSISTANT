import '../enums/proximity_level.dart';
import '../enums/risk_level.dart';
import '../enums/screen_position.dart';
import 'detection_result.dart';

class ObstacleAlert {
  const ObstacleAlert({
    required this.detection,
    required this.position,
    required this.proximity,
    required this.riskLevel,
    required this.timestamp,
    this.importanceScore = 0,
  });

  final DetectionResult detection;
  final ScreenPosition position;
  final ProximityLevel proximity;
  final RiskLevel riskLevel;
  final DateTime timestamp;
  final double importanceScore;

  String get spokenDescription {
    final label = detection.label.isEmpty
        ? 'Object'
        : '${detection.label[0].toUpperCase()}${detection.label.substring(1)}';
    final proximityText = proximity == ProximityLevel.veryNear
        ? ' very close'
        : '';
    final positionText = switch (position) {
      ScreenPosition.left || ScreenPosition.centerLeft => 'on the left',
      ScreenPosition.center => 'ahead',
      ScreenPosition.centerRight || ScreenPosition.right => 'on the right',
    };
    return '$label$proximityText $positionText';
  }

  @override
  String toString() =>
      'ObstacleAlert(${detection.label}, ${riskLevel.label}, ${position.label}, ${proximity.label})';
}
