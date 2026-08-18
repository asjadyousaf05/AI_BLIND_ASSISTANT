enum ProximityLevel {
  far,
  medium,
  near,
  veryNear;

  String get label {
    switch (this) {
      case ProximityLevel.far:
        return 'far away';
      case ProximityLevel.medium:
        return 'nearby';
      case ProximityLevel.near:
        return 'close';
      case ProximityLevel.veryNear:
        return 'very close';
    }
  }

  int get urgency {
    switch (this) {
      case ProximityLevel.far:
        return 1;
      case ProximityLevel.medium:
        return 2;
      case ProximityLevel.near:
        return 3;
      case ProximityLevel.veryNear:
        return 4;
    }
  }
}
