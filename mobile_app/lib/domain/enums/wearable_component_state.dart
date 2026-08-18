enum WearableComponentState {
  unavailable,
  loading,
  ready,
  active,
  paused,
  recovering,
  error;

  static WearableComponentState fromWireName(String value) {
    return values.firstWhere(
      (state) => state.name == value,
      orElse: () =>
          throw FormatException('Unsupported wearable component state: $value'),
    );
  }
}
