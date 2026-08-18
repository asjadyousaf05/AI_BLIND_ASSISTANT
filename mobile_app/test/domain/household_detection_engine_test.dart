import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/domain/enums/detection_environment_mode.dart';
import 'package:ai_blind_assistant/domain/services/household_detection_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HouseholdDetectionEngine', () {
    const engine = HouseholdDetectionEngine();

    test('categorizes household items accurately', () {
      expect(engine.categoryFor('chair'), HouseholdCategory.furniture);
      expect(engine.categoryFor('couch'), HouseholdCategory.furniture);
      expect(engine.categoryFor('refrigerator'), HouseholdCategory.appliance);
      expect(engine.categoryFor('microwave'), HouseholdCategory.appliance);
      expect(engine.categoryFor('bottle'), HouseholdCategory.kitchenware);
      expect(engine.categoryFor('cup'), HouseholdCategory.kitchenware);
      expect(engine.categoryFor('laptop'), HouseholdCategory.electronic);
      expect(engine.categoryFor('cell phone'), HouseholdCategory.electronic);
      expect(engine.categoryFor('backpack'), HouseholdCategory.personal);
      expect(engine.categoryFor('car'), HouseholdCategory.general);
    });

    test('identifies domestic items correctly', () {
      expect(engine.isHouseholdItem('chair'), isTrue);
      expect(engine.isHouseholdItem('refrigerator'), isTrue);
      expect(engine.isHouseholdItem('cup'), isTrue);
      expect(engine.isHouseholdItem('airplane'), isFalse);
      expect(engine.isHouseholdItem('truck'), isFalse);
    });

    test('boosts confidence in indoor mode for household items', () {
      final detections = [
        DetectionResult(
          classId: 56,
          label: 'chair',
          confidence: 0.50,
          boundingBox: const BoundingBox(
            left: 0.2,
            top: 0.2,
            right: 0.5,
            bottom: 0.8,
          ),
          frameTimestamp: DateTime.now(),
        ),
        DetectionResult(
          classId: 2,
          label: 'car',
          confidence: 0.50,
          boundingBox: const BoundingBox(
            left: 0.5,
            top: 0.2,
            right: 0.8,
            bottom: 0.8,
          ),
          frameTimestamp: DateTime.now(),
        ),
      ];

      final indoorProcessed = engine.process(
        rawDetections: detections,
        mode: DetectionEnvironmentMode.indoor,
        indoorConfidenceBoost: 0.05,
      );

      expect(indoorProcessed[0].confidence, closeTo(0.55, 0.001));
      expect(
        indoorProcessed[1].confidence,
        closeTo(0.50, 0.001),
      ); // Non-household unboosted
    });

    test('does not boost confidence in outdoor mode', () {
      final detections = [
        DetectionResult(
          classId: 56,
          label: 'chair',
          confidence: 0.50,
          boundingBox: const BoundingBox(
            left: 0.2,
            top: 0.2,
            right: 0.5,
            bottom: 0.8,
          ),
          frameTimestamp: DateTime.now(),
        ),
      ];

      final outdoorProcessed = engine.process(
        rawDetections: detections,
        mode: DetectionEnvironmentMode.outdoor,
      );

      expect(outdoorProcessed[0].confidence, closeTo(0.50, 0.001));
    });
  });
}
