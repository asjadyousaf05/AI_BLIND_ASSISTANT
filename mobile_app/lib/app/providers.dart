import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/logging/safe_debug_logger.dart';
import '../domain/entities/app_settings.dart';
import '../domain/enums/detection_environment_mode.dart';
import '../domain/enums/detection_sensitivity.dart';
import '../domain/enums/feedback_mode.dart';
import '../domain/enums/operating_mode.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/household_detection_engine.dart';
import '../domain/services/multi_model_fusion_service.dart';
import '../domain/services/ocr_service.dart';
import '../infrastructure/ocr/ml_kit_ocr_service.dart';
import '../infrastructure/storage/local_settings_repository.dart';
import 'app.dart' show appNavigatorKey;

final appLoggerProvider = Provider<AppLogger>((ref) => const SafeDebugLogger());

/// Provides the application-level [NavigatorState] key for voice navigation.
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => appNavigatorKey,
);

/// Household detection enhancer service.
final householdDetectionEngineProvider = Provider<HouseholdDetectionEngine>((
  ref,
) {
  return const HouseholdDetectionEngine();
});

/// Multi-model detection fusion service.
final multiModelFusionServiceProvider = Provider<MultiModelFusionService>((
  ref,
) {
  return const MultiModelFusionService();
});

/// On-device OCR service. Disposed when the provider container is destroyed.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(service.dispose);
  return service;
});

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

  void setHandsFreeAssistantEnabled(bool enabled) {
    state = state.copyWith(handsFreeAssistantEnabled: enabled);
    _save();
  }

  void setEnvironmentMode(DetectionEnvironmentMode mode) {
    state = state.copyWith(environmentMode: mode);
    _save();
  }

  Future<void> saveSettings() async {
    await _save();
  }
}

/// Actions that can be triggered on the OCR scanner screen via voice commands.
enum OcrActionTrigger {
  capture,
  stopSpeaking,
  readAgain,
  reset,
  pause,
  resume,
  previous,
  next,
  repeat,
  restart,
  last,
  goToLine,
  spell,
  setLearningMode,
  setNormalMode,
  setSkimMode,
  switchCamera,
  enableTorch,
  disableTorch,
  copyText,
}

/// A typed Scanner action request, including an optional one-based line target.
class OcrActionRequest {
  const OcrActionRequest(this.action, {this.lineNumber});

  final OcrActionTrigger action;
  final int? lineNumber;
}

class OcrActionTriggerController extends Notifier<OcrActionRequest?> {
  @override
  OcrActionRequest? build() => null;

  void trigger(OcrActionTrigger action, {int? lineNumber}) {
    state = OcrActionRequest(action, lineNumber: lineNumber);
  }

  void clear() {
    state = null;
  }
}

/// Global trigger for OCR scanner actions invoked by voice assistant.
final ocrActionTriggerProvider =
    NotifierProvider<OcrActionTriggerController, OcrActionRequest?>(
      OcrActionTriggerController.new,
    );
