import '../entities/detection_result.dart';
import '../entities/obstacle_alert.dart';

abstract interface class RiskAssessor {
  List<ObstacleAlert> assess(List<DetectionResult> detections);
}
