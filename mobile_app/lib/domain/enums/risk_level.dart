enum RiskLevel {
  low,
  moderate,
  high,
  critical;

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'low risk';
      case RiskLevel.moderate:
        return 'moderate risk';
      case RiskLevel.high:
        return 'high risk';
      case RiskLevel.critical:
        return 'critical';
    }
  }

  int get priority {
    switch (this) {
      case RiskLevel.low:
        return 1;
      case RiskLevel.moderate:
        return 2;
      case RiskLevel.high:
        return 3;
      case RiskLevel.critical:
        return 4;
    }
  }

  bool get requiresAlert =>
      this == RiskLevel.moderate ||
      this == RiskLevel.high ||
      this == RiskLevel.critical;
}
