enum CameraPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  restricted;

  bool get isGranted => this == CameraPermissionStatus.granted;

  bool get isDenied =>
      this == CameraPermissionStatus.denied ||
      this == CameraPermissionStatus.permanentlyDenied;

  bool get isPermanentlyDenied =>
      this == CameraPermissionStatus.permanentlyDenied;

  String get label => switch (this) {
    CameraPermissionStatus.unknown => 'Unknown',
    CameraPermissionStatus.granted => 'Granted',
    CameraPermissionStatus.denied => 'Denied',
    CameraPermissionStatus.permanentlyDenied => 'Permanently denied',
    CameraPermissionStatus.restricted => 'Restricted',
  };
}
