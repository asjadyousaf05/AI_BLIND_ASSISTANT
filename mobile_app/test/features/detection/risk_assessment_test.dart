import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/domain/enums/proximity_level.dart';
import 'package:ai_blind_assistant/domain/enums/risk_level.dart';
import 'package:ai_blind_assistant/domain/enums/screen_position.dart';
import 'package:ai_blind_assistant/infrastructure/detection/obstacle_risk_assessor.dart';

void main() {
  late ObstacleRiskAssessor assessor;

  setUp(() {
    assessor = ObstacleRiskAssessor();
  });

  DetectionResult makeDetection({
    double left = 0.3,
    double top = 0.3,
    double right = 0.7,
    double bottom = 0.9,
    int classId = 0,
    String label = 'person',
    double confidence = 0.9,
  }) {
    return DetectionResult(
      classId: classId,
      label: label,
      confidence: confidence,
      boundingBox: BoundingBox(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      frameTimestamp: DateTime(2024, 1, 1),
    );
  }

  group('Position classification', () {
    // UT-RISK-001: Center position detection
    test('UT-RISK-001: classifies centered object as center', () {
      final det = makeDetection(left: 0.35, right: 0.65);
      final alerts = assessor.assess([det]);
      expect(alerts[0].position, ScreenPosition.center);
    });

    // UT-RISK-002: Left position detection
    test('UT-RISK-002: classifies far-left object', () {
      final det = makeDetection(left: 0.0, right: 0.15);
      final alerts = assessor.assess([det]);
      expect(alerts[0].position, ScreenPosition.left);
    });

    // UT-RISK-003: Right position detection
    test('UT-RISK-003: classifies far-right object', () {
      final det = makeDetection(left: 0.85, right: 1.0);
      final alerts = assessor.assess([det]);
      expect(alerts[0].position, ScreenPosition.right);
    });
  });

  group('Proximity estimation', () {
    // UT-RISK-004: Large object is very near
    test('UT-RISK-004: large centered object is very near', () {
      final det = makeDetection(left: 0.1, top: 0.1, right: 0.9, bottom: 1.0);
      final alerts = assessor.assess([det]);
      expect(alerts[0].proximity, ProximityLevel.veryNear);
    });

    // UT-RISK-005: Small object is far
    test('UT-RISK-005: small object is far', () {
      final det = makeDetection(left: 0.4, top: 0.1, right: 0.5, bottom: 0.2);
      final alerts = assessor.assess([det]);
      expect(alerts[0].proximity, ProximityLevel.far);
    });
  });

  group('Risk level computation', () {
    // UT-RISK-006: Center + very near = critical
    test('UT-RISK-006: center + very near = critical', () {
      final det = makeDetection(left: 0.1, top: 0.1, right: 0.9, bottom: 1.0);
      final alerts = assessor.assess([det]);
      expect(alerts[0].riskLevel, RiskLevel.critical);
    });

    // UT-RISK-007: Small far object = low risk
    test('UT-RISK-007: small far object = low risk', () {
      final det = makeDetection(left: 0.4, top: 0.1, right: 0.5, bottom: 0.2);
      final alerts = assessor.assess([det]);
      expect(alerts[0].riskLevel, RiskLevel.low);
    });
  });

  group('Alert prioritisation', () {
    // UT-RISK-008: Alerts sorted by risk then proximity
    test('UT-RISK-008: alerts sorted by risk then proximity', () {
      final farSmall = makeDetection(
        left: 0.4,
        top: 0.1,
        right: 0.5,
        bottom: 0.2,
        label: 'cat',
      );
      final nearLarge = makeDetection(
        left: 0.1,
        top: 0.1,
        right: 0.9,
        bottom: 1.0,
        label: 'person',
      );

      final alerts = assessor.assess([farSmall, nearLarge]);
      expect(alerts[0].detection.label, 'person');
      expect(alerts[1].detection.label, 'cat');
    });

    // UT-RISK-009: Empty input returns empty
    test('UT-RISK-009: empty detections returns empty alerts', () {
      final alerts = assessor.assess([]);
      expect(alerts, isEmpty);
    });

    // UT-RISK-010: Spoken description format
    test('UT-RISK-010: spoken description format', () {
      final det = makeDetection(left: 0.35, right: 0.65);
      final alerts = assessor.assess([det]);
      expect(alerts[0].spokenDescription, contains('Person'));
      expect(alerts[0].spokenDescription, contains('ahead'));
    });
  });
}
