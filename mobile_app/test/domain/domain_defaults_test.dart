import 'package:ai_blind_assistant/domain/entities/app_settings.dart';
import 'package:ai_blind_assistant/domain/entities/assistance_session.dart';
import 'package:ai_blind_assistant/domain/entities/detection_settings.dart';
import 'package:ai_blind_assistant/domain/entities/feedback_settings.dart';
import 'package:ai_blind_assistant/domain/entities/raspberry_pi_connection_state.dart';
import 'package:ai_blind_assistant/domain/enums/assistance_state.dart';
import 'package:ai_blind_assistant/domain/enums/connection_status.dart';
import 'package:ai_blind_assistant/domain/enums/detection_sensitivity.dart';
import 'package:ai_blind_assistant/domain/enums/feedback_mode.dart';
import 'package:ai_blind_assistant/domain/enums/operating_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UT-DOMAIN-001 app settings default to offline Mobile Mode', () {
    expect(AppSettings.defaults.preferredOperatingMode, OperatingMode.mobile);
    expect(AppSettings.defaults.feedbackSettings, FeedbackSettings.defaults);
    expect(AppSettings.defaults.detectionSettings, DetectionSettings.defaults);
  });

  test('UT-DOMAIN-002 feedback settings expose channel availability', () {
    expect(FeedbackSettings.defaults.mode, FeedbackMode.audioAndVibration);
    expect(FeedbackSettings.defaults.audioEnabled, isTrue);
    expect(FeedbackSettings.defaults.vibrationEnabled, isTrue);
  });

  test('UT-DOMAIN-003 detection settings default to medium sensitivity', () {
    expect(DetectionSettings.defaults.sensitivity, DetectionSensitivity.medium);
    expect(DetectionSettings.defaults.minimumConfidence, 0.45);
    expect(DetectionSettings.defaults.confidenceThreshold, 0.45);
  });

  test('UT-DOMAIN-004 assistance state active helper behaves correctly', () {
    expect(AssistanceState.active.isActive, isTrue);
    expect(AssistanceState.idle.isActive, isFalse);
    expect(AssistanceSession.idleMobile.isActive, isFalse);
  });

  test('UT-DOMAIN-005 operating mode labels are user safe', () {
    expect(OperatingMode.mobile.label, 'Mobile Mode');
    expect(OperatingMode.raspberryPi.label, 'Raspberry Pi Mode');
    expect(OperatingMode.mobile.description, contains('offline'));
  });

  test('UT-DOMAIN-006 Raspberry Pi state starts disconnected', () {
    expect(
      RaspberryPiConnectionState.disconnected.status,
      ConnectionStatus.disconnected,
    );
    expect(ConnectionStatus.disconnected.canRetry, isTrue);
    expect(ConnectionStatus.connected.canRetry, isFalse);
  });
}
