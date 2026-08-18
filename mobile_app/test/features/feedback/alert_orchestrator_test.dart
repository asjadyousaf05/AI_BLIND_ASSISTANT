import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/domain/entities/obstacle_alert.dart';
import 'package:ai_blind_assistant/domain/enums/proximity_level.dart';
import 'package:ai_blind_assistant/domain/enums/risk_level.dart';
import 'package:ai_blind_assistant/domain/enums/screen_position.dart';
import 'package:ai_blind_assistant/domain/services/tts_service.dart';
import 'package:ai_blind_assistant/domain/services/vibration_service.dart';
import 'package:ai_blind_assistant/infrastructure/feedback/feedback_alert_orchestrator.dart';

class FakeTtsService implements TtsService {
  final List<String> spokenTexts = [];
  final List<bool> interruptFlags = [];
  final List<double> spokenPans = [];
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(
    String text, {
    bool interrupt = false,
    double pan = 0.0,
  }) async {
    spokenTexts.add(text);
    interruptFlags.add(interrupt);
    spokenPans.add(pan);
    _speaking = true;
  }

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> stop() async {
    _speaking = false;
  }

  @override
  Future<void> dispose() async {
    _speaking = false;
  }
}

class FakeVibrationService implements VibrationService {
  final List<RiskLevel> vibratedLevels = [];
  int cancelCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> vibrateForRisk(RiskLevel level) async {
    vibratedLevels.add(level);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

void main() {
  late FakeTtsService tts;
  late FakeVibrationService vibration;
  late FeedbackAlertOrchestrator orchestrator;

  ObstacleAlert makeAlert({
    String label = 'person',
    RiskLevel riskLevel = RiskLevel.high,
    ScreenPosition position = ScreenPosition.center,
    ProximityLevel proximity = ProximityLevel.near,
  }) {
    return ObstacleAlert(
      detection: DetectionResult(
        classId: 0,
        label: label,
        confidence: 0.9,
        boundingBox: const BoundingBox(
          left: 0.3,
          top: 0.3,
          right: 0.7,
          bottom: 0.9,
        ),
        frameTimestamp: DateTime(2024, 1, 1),
      ),
      position: position,
      proximity: proximity,
      riskLevel: riskLevel,
      timestamp: DateTime.now(),
    );
  }

  setUp(() {
    tts = FakeTtsService();
    vibration = FakeVibrationService();
    orchestrator = FeedbackAlertOrchestrator(
      ttsService: tts,
      vibrationService: vibration,
      cooldownSeconds: 3,
      vibrationEnabled: true,
      minimumAnnouncementInterval: Duration.zero,
    );
  });

  group('FeedbackAlertOrchestrator', () {
    // UT-ALERT-001: Speaks top alert
    test('UT-ALERT-001: speaks the highest priority alert', () async {
      final alerts = [
        makeAlert(label: 'person', riskLevel: RiskLevel.critical),
        makeAlert(label: 'car', riskLevel: RiskLevel.moderate),
      ];

      await orchestrator.processAlerts(alerts);

      expect(tts.spokenTexts.length, 1);
      expect(tts.spokenTexts.first, contains('Person'));
    });

    // UT-ALERT-002: Vibrates for risk level
    test('UT-ALERT-002: vibrates matching risk level', () async {
      final alerts = [makeAlert(riskLevel: RiskLevel.high)];
      await orchestrator.processAlerts(alerts);

      expect(vibration.vibratedLevels, [RiskLevel.high]);
    });

    // UT-ALERT-003: Respects cooldown
    test('UT-ALERT-003: does not re-announce within cooldown', () async {
      final alerts = [makeAlert()];

      await orchestrator.processAlerts(alerts);
      await orchestrator.processAlerts(alerts);

      expect(tts.spokenTexts.length, 1);
    });

    // UT-ALERT-004: Critical interrupts lower risk
    test('UT-ALERT-004: critical alert bypasses cooldown', () async {
      final moderate = [makeAlert(riskLevel: RiskLevel.moderate)];
      final critical = [makeAlert(riskLevel: RiskLevel.critical)];

      await orchestrator.processAlerts(moderate);
      await orchestrator.processAlerts(critical);

      expect(tts.spokenTexts.length, 2);
    });

    // UT-ALERT-005: Vibration disabled
    test('UT-ALERT-005: skips vibration when disabled', () async {
      orchestrator.vibrationEnabled = false;
      await orchestrator.processAlerts([makeAlert()]);

      expect(vibration.vibratedLevels, isEmpty);
    });

    // UT-ALERT-006: Stop clears state
    test('UT-ALERT-006: stop clears cooldown state', () async {
      await orchestrator.processAlerts([makeAlert()]);
      await orchestrator.stop();
      await orchestrator.processAlerts([makeAlert()]);

      expect(tts.spokenTexts.length, 2);
    });

    // UT-ALERT-007: Empty alerts does nothing
    test('UT-ALERT-007: empty alerts does nothing', () async {
      await orchestrator.processAlerts([]);
      expect(tts.spokenTexts, isEmpty);
      expect(vibration.vibratedLevels, isEmpty);
    });

    // UT-ALERT-008: Spoken description format
    test('UT-ALERT-008: spoken description includes label and position', () {
      final alert = makeAlert(
        label: 'person',
        position: ScreenPosition.center,
        proximity: ProximityLevel.near,
      );
      expect(alert.spokenDescription, contains('Person'));
      expect(alert.spokenDescription, contains('ahead'));
      expect(alert.spokenDescription, 'Person ahead');
    });

    // UT-ALERT-009: Different objects have separate cooldowns
    test('UT-ALERT-009: different labels have separate cooldowns', () async {
      final personAlert = [makeAlert(label: 'person')];
      final carAlert = [makeAlert(label: 'car')];

      await orchestrator.processAlerts(personAlert);
      await orchestrator.processAlerts(carAlert);

      expect(tts.spokenTexts.length, 2);
    });

    test(
      'UT-ALERT-011: same class uses one cooldown across positions',
      () async {
        await orchestrator.processAlerts([
          makeAlert(position: ScreenPosition.left),
        ]);
        await orchestrator.processAlerts([
          makeAlert(position: ScreenPosition.right),
        ]);

        expect(tts.spokenTexts.length, 1);
      },
    );

    test('UT-ALERT-012: low-risk objects are not announced', () async {
      await orchestrator.processAlerts([makeAlert(riskLevel: RiskLevel.low)]);

      expect(tts.spokenTexts, isEmpty);
      expect(vibration.vibratedLevels, isEmpty);
    });

    test(
      'UT-ALERT-013: maps screen positions to spatial stereo pan values',
      () async {
        await orchestrator.processAlerts([
          makeAlert(label: 'person', position: ScreenPosition.left),
        ]);
        expect(tts.spokenPans.last, closeTo(-0.85, 0.01));

        // Wait for cooldown or use different label
        await orchestrator.processAlerts([
          makeAlert(label: 'chair', position: ScreenPosition.center),
        ]);
        expect(tts.spokenPans.last, closeTo(0.0, 0.01));

        await orchestrator.processAlerts([
          makeAlert(label: 'car', position: ScreenPosition.right),
        ]);
        expect(tts.spokenPans.last, closeTo(0.85, 0.01));
      },
    );

    // UT-ALERT-010: Dispose stops TTS
    test('UT-ALERT-010: dispose stops services', () async {
      await orchestrator.processAlerts([makeAlert()]);
      await orchestrator.dispose();

      expect(tts.isSpeaking, isFalse);
    });
  });
}
