enum CameraState {
  uninitialized,
  loading,
  ready,
  previewing,
  stopping,
  unavailable,
  error;

  bool get isActive =>
      this == CameraState.ready || this == CameraState.previewing;

  String get label => switch (this) {
    CameraState.uninitialized => 'Camera not started',
    CameraState.loading => 'Camera loading',
    CameraState.ready => 'Camera ready',
    CameraState.previewing => 'Camera previewing',
    CameraState.stopping => 'Camera stopping',
    CameraState.unavailable => 'Camera unavailable',
    CameraState.error => 'Camera error',
  };
}
