enum DetectionSensitivity {
  low,
  medium,
  high;

  String get label => switch (this) {
    DetectionSensitivity.low => 'Low',
    DetectionSensitivity.medium => 'Medium',
    DetectionSensitivity.high => 'High',
  };
}
