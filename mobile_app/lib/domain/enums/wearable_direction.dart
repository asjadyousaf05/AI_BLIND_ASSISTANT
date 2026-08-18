enum WearableDirection {
  left,
  center,
  right;

  static WearableDirection fromWireName(String value) {
    return values.firstWhere(
      (direction) => direction.name == value,
      orElse: () =>
          throw FormatException('Unsupported horizontal direction: $value'),
    );
  }
}
