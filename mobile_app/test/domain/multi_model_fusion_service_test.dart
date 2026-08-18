import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/domain/services/multi_model_fusion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiModelFusionService', () {
    const fusion = MultiModelFusionService(iouThreshold: 0.45);
    final now = DateTime.now();

    test('returns empty when both model outputs are empty', () {
      final results = fusion.fuse(
        primaryModelDetections: [],
        householdModelDetections: [],
      );
      expect(results, isEmpty);
    });

    test('returns single model output when the other is empty', () {
      final single = [
        DetectionResult(
          classId: 56,
          label: 'chair',
          confidence: 0.70,
          boundingBox: const BoundingBox(
            left: 0.1,
            top: 0.1,
            right: 0.4,
            bottom: 0.6,
          ),
          frameTimestamp: now,
        ),
      ];

      final results = fusion.fuse(
        primaryModelDetections: single,
        householdModelDetections: [],
      );
      expect(results.length, 1);
      expect(results.first.label, 'chair');
    });

    test('fuses overlapping detections from both models into weighted box', () {
      final primary = [
        DetectionResult(
          classId: 56,
          label: 'chair',
          confidence: 0.60,
          boundingBox: const BoundingBox(
            left: 0.10,
            top: 0.10,
            right: 0.50,
            bottom: 0.70,
          ),
          frameTimestamp: now,
        ),
      ];

      final household = [
        DetectionResult(
          classId: 56,
          label: 'chair',
          confidence: 0.80,
          boundingBox: const BoundingBox(
            left: 0.12,
            top: 0.12,
            right: 0.52,
            bottom: 0.72,
          ),
          frameTimestamp: now,
        ),
      ];

      final fused = fusion.fuse(
        primaryModelDetections: primary,
        householdModelDetections: household,
      );

      // Overlapping detections merged into 1 fused detection with highest confidence
      expect(fused.length, 1);
      expect(fused.first.label, 'chair');
      expect(fused.first.confidence, 0.80);
      expect(fused.first.boundingBox.left, greaterThan(0.10));
      expect(fused.first.boundingBox.left, lessThan(0.12));
    });

    test('preserves distinct non-overlapping objects from both models', () {
      final primary = [
        DetectionResult(
          classId: 0,
          label: 'person',
          confidence: 0.85,
          boundingBox: const BoundingBox(
            left: 0.05,
            top: 0.10,
            right: 0.35,
            bottom: 0.90,
          ),
          frameTimestamp: now,
        ),
      ];

      final household = [
        DetectionResult(
          classId: 60,
          label: 'dining table',
          confidence: 0.75,
          boundingBox: const BoundingBox(
            left: 0.50,
            top: 0.40,
            right: 0.95,
            bottom: 0.85,
          ),
          frameTimestamp: now,
        ),
      ];

      final fused = fusion.fuse(
        primaryModelDetections: primary,
        householdModelDetections: household,
      );

      expect(fused.length, 2);
    });
  });
}
