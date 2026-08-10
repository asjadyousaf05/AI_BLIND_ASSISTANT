import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/domain/entities/raw_inference_output.dart';
import 'package:ai_blind_assistant/infrastructure/detection/yolo_post_processor.dart';

void main() {
  group('BoundingBox', () {
    // UT-BBOX-001: Valid bounding box properties
    test('UT-BBOX-001: computes width, height, area, center', () {
      const box = BoundingBox(left: 0.1, top: 0.2, right: 0.5, bottom: 0.8);
      expect(box.width, closeTo(0.4, 1e-6));
      expect(box.height, closeTo(0.6, 1e-6));
      expect(box.area, closeTo(0.24, 1e-6));
      expect(box.centerX, closeTo(0.3, 1e-6));
      expect(box.centerY, closeTo(0.5, 1e-6));
      expect(box.isValid, isTrue);
    });

    // UT-BBOX-002: IoU calculation for overlapping boxes
    test('UT-BBOX-002: computes IoU for overlapping boxes', () {
      const box1 = BoundingBox(left: 0.0, top: 0.0, right: 0.4, bottom: 0.4);
      const box2 = BoundingBox(left: 0.2, top: 0.2, right: 0.6, bottom: 0.6);
      final iou = box1.iou(box2);
      // Intersection: [0.2,0.2]->[0.4,0.4] = 0.2*0.2 = 0.04
      // Union: 0.16 + 0.16 - 0.04 = 0.28
      expect(iou, closeTo(0.04 / 0.28, 1e-4));
    });

    // UT-BBOX-003: IoU is zero for non-overlapping boxes
    test('UT-BBOX-003: IoU is zero for non-overlapping boxes', () {
      const box1 = BoundingBox(left: 0.0, top: 0.0, right: 0.2, bottom: 0.2);
      const box2 = BoundingBox(left: 0.5, top: 0.5, right: 0.8, bottom: 0.8);
      expect(box1.iou(box2), 0.0);
    });

    // UT-BBOX-004: Invalid bounding box detection
    test('UT-BBOX-004: detects invalid bounding box', () {
      const zeroArea = BoundingBox(
        left: 0.5,
        top: 0.5,
        right: 0.5,
        bottom: 0.5,
      );
      expect(zeroArea.isValid, isFalse);
    });

    // UT-BBOX-005: Equality and hashCode
    test('UT-BBOX-005: equality and hashCode', () {
      const a = BoundingBox(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      const b = BoundingBox(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('DetectionResult', () {
    // UT-DET-001: Detection result properties
    test('UT-DET-001: exposes normalized coordinates', () {
      final result = DetectionResult(
        classId: 0,
        label: 'person',
        confidence: 0.95,
        boundingBox: const BoundingBox(
          left: 0.1,
          top: 0.2,
          right: 0.5,
          bottom: 0.8,
        ),
        frameTimestamp: DateTime(2024, 1, 1),
      );
      expect(result.normalizedCenterX, closeTo(0.3, 1e-6));
      expect(result.normalizedCenterY, closeTo(0.5, 1e-6));
      expect(result.normalizedWidth, closeTo(0.4, 1e-6));
      expect(result.normalizedHeight, closeTo(0.6, 1e-6));
      expect(result.normalizedArea, closeTo(0.24, 1e-6));
    });
  });

  group('YoloPostProcessor', () {
    late YoloPostProcessor processor;
    late List<String> labels;

    setUp(() {
      labels = List.generate(80, (i) => 'class_$i');
      labels[0] = 'person';
      labels[1] = 'bicycle';
      labels[2] = 'car';
      processor = YoloPostProcessor(labels: labels);
    });

    RawInferenceOutput buildFakeOutput({
      required int numCandidates,
      required List<_FakeDetection> detections,
    }) {
      final valuesPerCandidate = 84;
      final data = List<double>.filled(valuesPerCandidate * numCandidates, 0.0);

      for (final det in detections) {
        // Set bbox: row 0=cx, row 1=cy, row 2=w, row 3=h
        data[0 * numCandidates + det.index] = det.cx * 320;
        data[1 * numCandidates + det.index] = det.cy * 320;
        data[2 * numCandidates + det.index] = det.w * 320;
        data[3 * numCandidates + det.index] = det.h * 320;

        // Set class score
        data[(4 + det.classId) * numCandidates + det.index] = det.score;
      }

      return RawInferenceOutput(
        data: data,
        outputShape: [1, valuesPerCandidate, numCandidates],
        inferenceTimeMs: 50,
        timestamp: DateTime.now(),
        inputWidth: 320,
        inputHeight: 320,
      );
    }

    // UT-POST-001: Filters below confidence threshold
    test('UT-POST-001: filters detections below confidence threshold', () {
      final output = buildFakeOutput(
        numCandidates: 5,
        detections: [
          _FakeDetection(
            index: 0,
            cx: 0.5,
            cy: 0.5,
            w: 0.3,
            h: 0.3,
            classId: 0,
            score: 0.9,
          ),
          _FakeDetection(
            index: 1,
            cx: 0.2,
            cy: 0.2,
            w: 0.1,
            h: 0.1,
            classId: 1,
            score: 0.2,
          ),
        ],
      );

      final results = processor.process(output, confidenceThreshold: 0.4);
      expect(results.length, 1);
      expect(results[0].label, 'person');
    });

    // UT-POST-002: NMS suppresses overlapping same-class detections
    test('UT-POST-002: NMS suppresses overlapping same-class detections', () {
      final output = buildFakeOutput(
        numCandidates: 3,
        detections: [
          _FakeDetection(
            index: 0,
            cx: 0.5,
            cy: 0.5,
            w: 0.3,
            h: 0.3,
            classId: 0,
            score: 0.9,
          ),
          _FakeDetection(
            index: 1,
            cx: 0.52,
            cy: 0.52,
            w: 0.3,
            h: 0.3,
            classId: 0,
            score: 0.8,
          ),
          _FakeDetection(
            index: 2,
            cx: 0.1,
            cy: 0.1,
            w: 0.1,
            h: 0.1,
            classId: 0,
            score: 0.7,
          ),
        ],
      );

      final results = processor.process(
        output,
        confidenceThreshold: 0.4,
        iouThreshold: 0.45,
      );
      expect(results.length, 2); // first and third survive, second suppressed
      expect(results[0].confidence, 0.9);
      expect(results[1].confidence, 0.7);
    });

    // UT-POST-003: NMS does not suppress different-class detections
    test('UT-POST-003: NMS does not suppress different-class detections', () {
      final output = buildFakeOutput(
        numCandidates: 2,
        detections: [
          _FakeDetection(
            index: 0,
            cx: 0.5,
            cy: 0.5,
            w: 0.3,
            h: 0.3,
            classId: 0,
            score: 0.9,
          ),
          _FakeDetection(
            index: 1,
            cx: 0.5,
            cy: 0.5,
            w: 0.3,
            h: 0.3,
            classId: 2,
            score: 0.85,
          ),
        ],
      );

      final results = processor.process(output, confidenceThreshold: 0.4);
      expect(results.length, 2);
    });

    // UT-POST-004: Class filtering with allowedClassIds
    test('UT-POST-004: filters by allowed class IDs', () {
      final output = buildFakeOutput(
        numCandidates: 3,
        detections: [
          _FakeDetection(
            index: 0,
            cx: 0.5,
            cy: 0.5,
            w: 0.3,
            h: 0.3,
            classId: 0,
            score: 0.9,
          ),
          _FakeDetection(
            index: 1,
            cx: 0.2,
            cy: 0.2,
            w: 0.1,
            h: 0.1,
            classId: 2,
            score: 0.85,
          ),
          _FakeDetection(
            index: 2,
            cx: 0.8,
            cy: 0.8,
            w: 0.2,
            h: 0.2,
            classId: 1,
            score: 0.7,
          ),
        ],
      );

      final results = processor.process(
        output,
        confidenceThreshold: 0.4,
        allowedClassIds: {0, 1},
      );
      expect(results.length, 2);
      expect(results.any((r) => r.label == 'car'), isFalse);
    });

    // UT-POST-005: Empty output returns empty list
    test('UT-POST-005: handles empty output', () {
      final output = RawInferenceOutput(
        data: List.filled(84 * 10, 0.0),
        outputShape: [1, 84, 10],
        inferenceTimeMs: 10,
        timestamp: DateTime.now(),
        inputWidth: 320,
        inputHeight: 320,
      );

      final results = processor.process(output, confidenceThreshold: 0.4);
      expect(results, isEmpty);
    });

    // UT-POST-006: Invalid data length returns empty list
    test('UT-POST-006: returns empty for mismatched data length', () {
      final output = RawInferenceOutput(
        data: [1.0, 2.0, 3.0],
        outputShape: [1, 84, 2100],
        inferenceTimeMs: 10,
        timestamp: DateTime.now(),
        inputWidth: 320,
        inputHeight: 320,
      );

      final results = processor.process(output, confidenceThreshold: 0.4);
      expect(results, isEmpty);
    });

    // UT-POST-007: Bbox coordinates are clamped to [0, 1]
    test('UT-POST-007: clamps bounding box to valid range', () {
      final output = buildFakeOutput(
        numCandidates: 1,
        detections: [
          _FakeDetection(
            index: 0,
            cx: 0.95,
            cy: 0.95,
            w: 0.5,
            h: 0.5,
            classId: 0,
            score: 0.9,
          ),
        ],
      );

      final results = processor.process(output, confidenceThreshold: 0.4);
      expect(results.length, 1);
      expect(results[0].boundingBox.right, lessThanOrEqualTo(1.0));
      expect(results[0].boundingBox.bottom, lessThanOrEqualTo(1.0));
    });

    // UT-POST-008: Results sorted by confidence
    test('UT-POST-008: results ordered by confidence descending', () {
      final output = buildFakeOutput(
        numCandidates: 3,
        detections: [
          _FakeDetection(
            index: 0,
            cx: 0.2,
            cy: 0.2,
            w: 0.1,
            h: 0.1,
            classId: 0,
            score: 0.6,
          ),
          _FakeDetection(
            index: 1,
            cx: 0.5,
            cy: 0.5,
            w: 0.1,
            h: 0.1,
            classId: 1,
            score: 0.9,
          ),
          _FakeDetection(
            index: 2,
            cx: 0.8,
            cy: 0.8,
            w: 0.1,
            h: 0.1,
            classId: 2,
            score: 0.75,
          ),
        ],
      );

      final results = processor.process(output, confidenceThreshold: 0.4);
      expect(results.length, 3);
      expect(results[0].confidence, 0.9);
      expect(results[1].confidence, 0.75);
      expect(results[2].confidence, 0.6);
    });

    test('UT-POST-009: supports candidate-major output metadata', () {
      const candidates = 2;
      const features = 84;
      final data = List<double>.filled(candidates * features, 0);
      data[0 * features + 0] = 160;
      data[0 * features + 1] = 160;
      data[0 * features + 2] = 128;
      data[0 * features + 3] = 128;
      data[0 * features + 4] = 0.9;

      final results = processor.process(
        RawInferenceOutput(
          data: data,
          outputShape: const [1, candidates, features],
          inferenceTimeMs: 10,
          timestamp: DateTime(2024),
          inputWidth: 320,
          inputHeight: 320,
        ),
        confidenceThreshold: 0.4,
      );

      expect(results, hasLength(1));
      expect(results.single.label, 'person');
    });

    test('UT-POST-010: removes letterbox padding from normalized boxes', () {
      const candidates = 1;
      const features = 84;
      final data = List<double>.filled(candidates * features, 0);
      data[0] = 0.5;
      data[1] = 0.5;
      data[2] = 0.5;
      data[3] = 0.5;
      data[4] = 0.9;

      final results = processor.process(
        RawInferenceOutput(
          data: data,
          outputShape: const [1, features, candidates],
          inferenceTimeMs: 10,
          timestamp: DateTime(2024),
          inputWidth: 320,
          inputHeight: 320,
          previewWidth: 640,
          previewHeight: 480,
          letterboxScale: 0.5,
          letterboxPaddingY: 40,
          boxCoordinatesNormalized: true,
        ),
        confidenceThreshold: 0.4,
      );

      expect(results, hasLength(1));
      final box = results.single.boundingBox;
      expect(box.left, closeTo(0.25, 1e-6));
      expect(box.top, closeTo(1 / 6, 1e-6));
      expect(box.right, closeTo(0.75, 1e-6));
      expect(box.bottom, closeTo(5 / 6, 1e-6));
    });
  });
}

class _FakeDetection {
  const _FakeDetection({
    required this.index,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.classId,
    required this.score,
  });

  final int index;
  final double cx, cy, w, h;
  final int classId;
  final double score;
}
