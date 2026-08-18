/// User-visible lifecycle of the phone's wearable connection and session.
enum WearableConnectionPhase {
  notConfigured,
  disconnected,
  discovering,
  deviceFound,
  pairing,
  paired,
  connecting,
  authenticating,
  connected,
  reconnecting,
  starting,
  running,
  paused,
  stopping,
  incompatible,
  authenticationFailed,
  unavailable,
  error;

  bool get isBusy => switch (this) {
    discovering ||
    pairing ||
    connecting ||
    authenticating ||
    reconnecting ||
    starting ||
    stopping => true,
    notConfigured ||
    disconnected ||
    deviceFound ||
    paired ||
    connected ||
    running ||
    paused ||
    incompatible ||
    authenticationFailed ||
    unavailable ||
    error => false,
  };

  bool get isConnected => switch (this) {
    connected || starting || running || paused || stopping => true,
    notConfigured ||
    disconnected ||
    discovering ||
    deviceFound ||
    pairing ||
    paired ||
    connecting ||
    authenticating ||
    reconnecting ||
    incompatible ||
    authenticationFailed ||
    unavailable ||
    error => false,
  };
}
