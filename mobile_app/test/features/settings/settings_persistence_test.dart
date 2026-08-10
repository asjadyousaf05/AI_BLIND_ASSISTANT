import 'package:ai_blind_assistant/core/errors/app_failure.dart';
import 'package:ai_blind_assistant/core/result/result.dart';
import 'package:ai_blind_assistant/domain/entities/app_settings.dart';
import 'package:ai_blind_assistant/domain/enums/detection_sensitivity.dart';
import 'package:ai_blind_assistant/domain/enums/feedback_mode.dart';
import 'package:ai_blind_assistant/domain/enums/operating_mode.dart';
import 'package:ai_blind_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings? stored;
  bool shouldFail = false;
  bool corruptData = false;

  @override
  Future<Result<AppSettings>> loadSettings() async {
    if (shouldFail) {
      return const Success(AppSettings.defaults);
    }
    if (corruptData) {
      return const Success(AppSettings.defaults);
    }
    if (stored != null) {
      return Success(stored!);
    }
    return const Success(AppSettings.defaults);
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    if (shouldFail) {
      return Failure(const StorageFailure(logMessage: 'Simulated failure'));
    }
    stored = settings;
    return const Success(null);
  }
}

void main() {
  group('Module 7: Local Settings Persistence', () {
    late InMemorySettingsRepository repo;
    late ProviderContainer container;

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      repo = InMemorySettingsRepository();
      container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('UT-SETTINGS-001: default settings are correct', () {
      final settings = container.read(appSettingsControllerProvider);
      expect(settings.preferredOperatingMode, OperatingMode.mobile);
      expect(settings.feedbackSettings.mode, FeedbackMode.audioAndVibration);
      expect(
        settings.detectionSettings.sensitivity,
        DetectionSensitivity.medium,
      );
      expect(settings.vibrationEnabled, isTrue);
      expect(settings.highContrastEnabled, isFalse);
      expect(settings.feedbackSettings.announcementCooldownSeconds, 5);
    });

    test('UT-SETTINGS-002: save and reload persists changes', () async {
      final controller = container.read(appSettingsControllerProvider.notifier);
      controller.selectFeedbackMode(FeedbackMode.vibration);
      controller.selectDetectionSensitivity(DetectionSensitivity.high);
      controller.setVibrationEnabled(false);

      await controller.loadFromStorage();
      final reloaded = container.read(appSettingsControllerProvider);
      expect(reloaded.feedbackSettings.mode, FeedbackMode.vibration);
      expect(reloaded.detectionSettings.sensitivity, DetectionSensitivity.high);
      expect(reloaded.vibrationEnabled, isFalse);
    });

    test('UT-SETTINGS-003: invalid cooldown clamped to range', () {
      final controller = container.read(appSettingsControllerProvider.notifier);
      controller.setAnnouncementCooldown(0);
      expect(
        container
            .read(appSettingsControllerProvider)
            .feedbackSettings
            .announcementCooldownSeconds,
        1,
      );
      controller.setAnnouncementCooldown(99);
      expect(
        container
            .read(appSettingsControllerProvider)
            .feedbackSettings
            .announcementCooldownSeconds,
        30,
      );
    });

    test('UT-SETTINGS-004: corrupted data returns defaults', () async {
      repo.corruptData = true;
      final controller = container.read(appSettingsControllerProvider.notifier);
      await controller.loadFromStorage();

      final settings = container.read(appSettingsControllerProvider);
      expect(settings, equals(AppSettings.defaults));
    });

    test('UT-SETTINGS-005: state synchronizes with UI provider', () {
      final controller = container.read(appSettingsControllerProvider.notifier);
      controller.selectOperatingMode(OperatingMode.raspberryPi);

      final settings = container.read(appSettingsControllerProvider);
      expect(settings.preferredOperatingMode, OperatingMode.raspberryPi);
    });
  });
}
