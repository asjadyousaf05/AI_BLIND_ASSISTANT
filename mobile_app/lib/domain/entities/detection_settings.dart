import '../enums/detection_sensitivity.dart';

class DetectionSettings {
  const DetectionSettings({
    required this.sensitivity,
    required this.minimumConfidence,
  });

  static const defaults = DetectionSettings(
    sensitivity: DetectionSensitivity.medium,
    minimumConfidence: 0.45,
  );

  final DetectionSensitivity sensitivity;
  final double minimumConfidence;

  /// Confidence threshold controlled by the user-facing sensitivity setting.
  double get confidenceThreshold => switch (sensitivity) {
    DetectionSensitivity.low => 0.60,
    DetectionSensitivity.medium => 0.45,
    DetectionSensitivity.high => 0.30,
  };

  DetectionSettings copyWith({
    DetectionSensitivity? sensitivity,
    double? minimumConfidence,
  }) {
    return DetectionSettings(
      sensitivity: sensitivity ?? this.sensitivity,
      minimumConfidence: minimumConfidence ?? this.minimumConfidence,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DetectionSettings &&
        other.sensitivity == sensitivity &&
        other.minimumConfidence == minimumConfidence;
  }

  @override
  int get hashCode => Object.hash(sensitivity, minimumConfidence);
}
