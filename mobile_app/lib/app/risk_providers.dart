import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/obstacle_alert.dart';
import '../domain/services/risk_assessor.dart';
import '../infrastructure/detection/obstacle_risk_assessor.dart';
import 'detection_providers.dart';

final riskAssessorProvider = Provider<RiskAssessor>((ref) {
  return ObstacleRiskAssessor();
});

final obstacleAlertsProvider = Provider<List<ObstacleAlert>>((ref) {
  final detections = ref.watch(detectionResultsProvider);
  if (detections.isEmpty) return [];

  final assessor = ref.read(riskAssessorProvider);
  return assessor.assess(detections);
});
