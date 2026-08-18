import '../entities/detection_result.dart';
import '../enums/detection_environment_mode.dart';

/// Categories of household objects for assistive vision.
enum HouseholdCategory {
  furniture('Furniture'),
  appliance('Kitchen & Appliance'),
  kitchenware('Kitchenware & Utensil'),
  electronic('Electronics & Devices'),
  personal('Personal Item'),
  hazard('Indoor Hazard'),
  general('General Object');

  const HouseholdCategory(this.label);
  final String label;
}

/// Household and domestic object detection enhancer.
///
/// Refines, specializes, and enhances on-device object detection for indoor
/// home environments. Applies household scene priors, domestic object
/// category tagging, and calibrated confidence thresholds.
class HouseholdDetectionEngine {
  const HouseholdDetectionEngine();

  /// Known domestic and household classes.
  static const Set<String> householdClasses = {
    // Furniture & Fixtures
    'chair',
    'couch',
    'bed',
    'dining table',
    'bench',
    'potted plant',
    'door',
    'desk',
    'shelf',
    'toilet',

    // Kitchen & Major Appliances
    'refrigerator',
    'microwave',
    'oven',
    'toaster',
    'sink',

    // Kitchenware & Eating Tools
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',

    // Electronics & Household Tools
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'clock',
    'book',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush',

    // Everyday Personal Carry Items
    'backpack',
    'umbrella',
    'handbag',
    'suitcase',
  };

  /// Returns the household category for a given object label.
  HouseholdCategory categoryFor(String label) {
    final lower = label.toLowerCase();
    return switch (lower) {
      'chair' ||
      'couch' ||
      'bed' ||
      'dining table' ||
      'bench' ||
      'desk' ||
      'shelf' ||
      'potted plant' => HouseholdCategory.furniture,
      'refrigerator' ||
      'microwave' ||
      'oven' ||
      'toaster' ||
      'sink' ||
      'toilet' => HouseholdCategory.appliance,
      'bottle' ||
      'wine glass' ||
      'cup' ||
      'fork' ||
      'knife' ||
      'spoon' ||
      'bowl' => HouseholdCategory.kitchenware,
      'tv' ||
      'laptop' ||
      'mouse' ||
      'remote' ||
      'keyboard' ||
      'cell phone' ||
      'clock' => HouseholdCategory.electronic,
      'backpack' ||
      'umbrella' ||
      'handbag' ||
      'suitcase' ||
      'book' ||
      'vase' ||
      'scissors' ||
      'hair drier' ||
      'toothbrush' ||
      'teddy bear' => HouseholdCategory.personal,
      'person' => HouseholdCategory.general,
      _ => HouseholdCategory.general,
    };
  }

  /// Whether the detected object is a domestic / household item.
  bool isHouseholdItem(String label) {
    return householdClasses.contains(label.toLowerCase());
  }

  /// Enhances detection results with indoor sensitivity and household categorization.
  List<DetectionResult> process({
    required List<DetectionResult> rawDetections,
    required DetectionEnvironmentMode mode,
    double indoorConfidenceBoost = 0.05,
  }) {
    if (rawDetections.isEmpty) return const [];

    final processed = <DetectionResult>[];

    for (final det in rawDetections) {
      final isHousehold = isHouseholdItem(det.label);

      // In indoor mode, boost confidence of valid household items slightly
      // so domestic objects in soft home lighting are not prematurely clipped.
      var adjustedConfidence = det.confidence;
      if (mode.isIndoor && isHousehold) {
        adjustedConfidence = (det.confidence + indoorConfidenceBoost).clamp(
          0.0,
          1.0,
        );
      }

      processed.add(
        DetectionResult(
          classId: det.classId,
          label: det.label,
          confidence: adjustedConfidence,
          boundingBox: det.boundingBox,
          frameTimestamp: det.frameTimestamp,
        ),
      );
    }

    return processed;
  }
}
