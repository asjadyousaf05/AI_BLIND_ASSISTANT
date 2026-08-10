enum WearableAssistanceState {
  idle,
  starting,
  running,
  paused,
  stopping,
  hardwareError;

  static WearableAssistanceState fromWireName(String value) {
    return switch (value) {
      'idle' => idle,
      'starting' => starting,
      'running' => running,
      'paused' => paused,
      'stopping' => stopping,
      'hardware_error' => hardwareError,
      _ => throw FormatException('Unsupported assistance state: $value'),
    };
  }

  String get wireName => switch (this) {
    idle => 'idle',
    starting => 'starting',
    running => 'running',
    paused => 'paused',
    stopping => 'stopping',
    hardwareError => 'hardware_error',
  };
}
