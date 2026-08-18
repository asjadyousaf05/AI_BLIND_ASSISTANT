/// Environmental scene mode for vision and object detection.
enum DetectionEnvironmentMode {
  auto('Auto (Adaptive)'),
  indoor('Indoor / Home Mode'),
  outdoor('Outdoor / Street Mode');

  const DetectionEnvironmentMode(this.label);

  final String label;

  bool get isIndoor => this == DetectionEnvironmentMode.indoor;
  bool get isOutdoor => this == DetectionEnvironmentMode.outdoor;
  bool get isAuto => this == DetectionEnvironmentMode.auto;
}
