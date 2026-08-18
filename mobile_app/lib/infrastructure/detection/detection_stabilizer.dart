import '../../domain/entities/detection_result.dart';

/// Requires spatially consistent detections across consecutive frames.
///
/// This deliberately remains a small persistence filter rather than a full
/// object tracker. It suppresses one-frame false positives without retaining
/// camera frames or creating a work queue.
class DetectionStabilizer {
  DetectionStabilizer({
    this.requiredConsecutiveHits = 2,
    this.minimumMatchIou = 0.2,
    this.maximumCenterDistance = 0.12,
  });

  final int requiredConsecutiveHits;
  final double minimumMatchIou;
  final double maximumCenterDistance;
  final List<_DetectionTrack> _tracks = [];

  List<DetectionResult> update(List<DetectionResult> detections) {
    for (final track in _tracks) {
      track.matched = false;
    }
    final matchableTracks = List<_DetectionTrack>.of(_tracks);

    final ordered = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    for (final detection in ordered) {
      _DetectionTrack? bestTrack;
      var bestScore = -1.0;
      for (final track in matchableTracks) {
        if (track.matched || track.detection.classId != detection.classId) {
          continue;
        }
        final iou = track.detection.boundingBox.iou(detection.boundingBox);
        final dx =
            track.detection.normalizedCenterX - detection.normalizedCenterX;
        final dy =
            track.detection.normalizedCenterY - detection.normalizedCenterY;
        final centerDistance = (dx * dx + dy * dy);
        final centerLimit = maximumCenterDistance * maximumCenterDistance;
        if (iou < minimumMatchIou && centerDistance > centerLimit) continue;
        final score = iou - centerDistance;
        if (score > bestScore) {
          bestScore = score;
          bestTrack = track;
        }
      }

      if (bestTrack == null) {
        _tracks.add(_DetectionTrack(detection));
      } else {
        bestTrack
          ..detection = detection
          ..consecutiveHits += 1
          ..matched = true;
      }
    }

    _tracks.removeWhere((track) => !track.matched);
    return _tracks
        .where((track) => track.consecutiveHits >= requiredConsecutiveHits)
        .map((track) => track.detection)
        .toList(growable: false);
  }

  void reset() => _tracks.clear();
}

class _DetectionTrack {
  _DetectionTrack(this.detection);

  DetectionResult detection;
  int consecutiveHits = 1;
  bool matched = true;
}
