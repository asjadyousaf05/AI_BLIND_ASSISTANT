/// Microphone permission status returned by [MicrophonePermissionService].
enum MicrophonePermissionStatus {
  /// Permission has not been requested yet.
  unknown,

  /// Permission was granted by the user.
  granted,

  /// Permission was denied for this session.
  denied,

  /// Permission was permanently denied; user must open device settings.
  permanentlyDenied,

  /// Permission is restricted by device policy or parental controls.
  restricted;

  bool get isGranted => this == MicrophonePermissionStatus.granted;
  bool get isDenied => this == MicrophonePermissionStatus.denied;
  bool get isPermanentlyDenied =>
      this == MicrophonePermissionStatus.permanentlyDenied;
}
