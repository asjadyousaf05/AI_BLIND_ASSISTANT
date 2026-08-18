import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/infrastructure/detection/detection_stabilizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DetectionResult detection({double offset = 0, int classId = 0}) {
    return DetectionResult(
      classId: classId,
      label: classId == 0 ? 'person' : 'chair',
      confidence: 0.9,
      boundingBox: BoundingBox(
        left: 0.30 + offset,
        top: 0.20,
        right: 0.70 + offset,
        bottom: 0.90,
      ),
      frameTimestamp: DateTime(2024),
    );
  }

  test('UT-STABILITY-001: suppresses a one-frame detection', () {
    final stabilizer = DetectionStabilizer();

    expect(stabilizer.update([detection()]), isEmpty);
    expect(stabilizer.update(const []), isEmpty);
  });

  test('UT-STABILITY-002: emits a spatial match on the second frame', () {
    final stabilizer = DetectionStabilizer();

    expect(stabilizer.update([detection()]), isEmpty);
    final stable = stabilizer.update([detection(offset: 0.01)]);

    expect(stable, hasLength(1));
    expect(stable.single.label, 'person');
  });

  test('UT-STABILITY-003: does not merge different classes', () {
    final stabilizer = DetectionStabilizer();

    expect(stabilizer.update([detection()]), isEmpty);
    expect(stabilizer.update([detection(classId: 56)]), isEmpty);
  });
}
