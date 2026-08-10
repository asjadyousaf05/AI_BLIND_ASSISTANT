import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/logging/safe_debug_logger.dart';
import '../domain/entities/app_settings.dart';
import '../domain/enums/detection_sensitivity.dart';
import '../domain/enums/feedback_mode.dart';
import '../domain/enums/operating_mode.dart';
import '../domain/repositories/settings_repository.dart';
import '../infrastructure/storage/local_settings_repository.dart';

final appLoggerProvider = Provider<AppLogger>((ref) => const SafeDebugLogger());

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository();
});

final appSettingsControllerProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return AppSettings.defaults;
  }

  Future<void> loadFromStorage() async {
    final repo = ref.read(settingsRepositoryProvider);
    final result = await repo.loadSettings();
    result.when(
      success: (settings) => state = settings,
      failure: (_) {
        // Keep defaults on failure
      },
    );
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveSettings(state);
  }

  void selectOperatingMode(OperatingMode mode) {
    state = state.copyWith(preferredOperatingMode: mode);
    _save();
  }

  void selectFeedbackMode(FeedbackMode mode) {
    state = state.copyWith(
      feedbackSettings: state.feedbackSettings.copyWith(mode: mode),
    );
    _save();
  }

  void selectDetectionSensitivity(DetectionSensitivity sensitivity) {
    state = state.copyWith(
      detectionSettings: state.detectionSettings.copyWith(
        sensitivity: sensitivity,
        minimumConfidence: switch (sensitivity) {
          DetectionSensitivity.low => 0.60,
          DetectionSensitivity.medium => 0.45,
          DetectionSensitivity.high => 0.30,
        },
      ),
    );
    _save();
  }

  void setVibrationEnabled(bool enabled) {
    state = state.copyWith(vibrationEnabled: enabled);
    _save();
  }

  void setAnnouncementCooldown(int seconds) {
    final clamped = seconds.clamp(1, 30);
    state = state.copyWith(
      feedbackSettings: state.feedbackSettings.copyWith(
        announcementCooldownSeconds: clamped,
      ),
    );
    _save();
  }

  void setHighContrastEnabled(bool enabled) {
    state = state.copyWith(highContrastEnabled: enabled);
    _save();
  }

  void setLargeTextEnabled(bool enabled) {
    state = state.copyWith(largeTextEnabled: enabled);
    _save();
  }

  void setReducedMotionEnabled(bool enabled) {
    state = state.copyWith(reducedMotionEnabled: enabled);
    _save();
  }

  Future<void> saveSettings() async {
    await _save();
  }
}
