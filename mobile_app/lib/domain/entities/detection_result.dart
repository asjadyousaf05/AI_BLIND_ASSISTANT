import 'bounding_box.dart';

class DetectionResult {
  const DetectionResult({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.frameTimestamp,
  });

  final int classId;
  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  final DateTime frameTimestamp;

  double get normalizedCenterX => boundingBox.centerX;
  double get normalizedCenterY => boundingBox.centerY;
  double get normalizedWidth => boundingBox.width;
  double get normalizedHeight => boundingBox.height;
  double get normalizedArea => boundingBox.area;

  @override
  bool operator ==(Object other) {
    return other is DetectionResult &&
        other.classId == classId &&
        other.confidence == confidence &&
        other.boundingBox == boundingBox;
  }

  @override
  int get hashCode => Object.hash(classId, confidence, boundingBox);

  @override
  String toString() =>
      'DetectionResult($label ${(confidence * 100).toStringAsFixed(1)}% at $boundingBox)';
}
