import '../enums/risk_level.dart';

abstract interface class VibrationService {
  Future<void> vibrateForRisk(RiskLevel level);
  Future<void> cancel();
  bool get isAvailable;
}
