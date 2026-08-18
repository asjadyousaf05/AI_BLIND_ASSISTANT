import '../entities/obstacle_alert.dart';

abstract interface class AlertOrchestrator {
  Future<void> processAlerts(List<ObstacleAlert> alerts);
  Future<void> stop();
  Future<void> dispose();
  bool get isActive;
}
