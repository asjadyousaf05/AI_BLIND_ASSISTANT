import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/assistant_session_state.dart';
import '../domain/enums/feedback_mode.dart';
import '../domain/services/alert_orchestrator.dart';
import '../domain/services/tts_service.dart';
import '../domain/services/vibration_service.dart';
import '../infrastructure/feedback/device_vibration_service.dart';
import '../infrastructure/feedback/feedback_alert_orchestrator.dart';
import '../infrastructure/feedback/flutter_tts_service.dart';
import 'assistant_providers.dart';
import 'assistant_session_controller.dart';
import 'providers.dart';
import 'risk_providers.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = ref.read(flutterTtsInstanceProvider);
  final service = FlutterTtsService(tts: tts);
  ref.onDispose(() => service.dispose());
  return service;
});

final vibrationServiceProvider = Provider<VibrationService>((ref) {
  return DeviceVibrationService();
});

final alertOrchestratorProvider = Provider<AlertOrchestrator>((ref) {
  final tts = ref.read(ttsServiceProvider);
  final vibration = ref.read(vibrationServiceProvider);
  final settings = ref.read(appSettingsControllerProvider);

  final orchestrator = FeedbackAlertOrchestrator(
    ttsService: tts,
    vibrationService: vibration,
    cooldownSeconds: settings.feedbackSettings.announcementCooldownSeconds,
    vibrationEnabled: settings.vibrationEnabled,
    feedbackMode: settings.feedbackSettings.mode,
  );

  ref.onDispose(() => orchestrator.dispose());
  return orchestrator;
});

final feedbackControllerProvider = NotifierProvider<FeedbackController, bool>(
  FeedbackController.new,
);

class FeedbackController extends Notifier<bool> {
  bool _running = false;
  String? _lastError;
  String? _lastWarning;

  String? get lastError => _lastError;
  String? get lastWarning => _lastWarning;

  @override
  bool build() {
    ref.listen(obstacleAlertsProvider, (previous, next) {
      if (_running && next.isNotEmpty) {
        unawaited(_processAlerts());
      }
    });
    ref.onDispose(_cleanup);
    return false;
  }

  AlertOrchestrator get _orchestrator => ref.read(alertOrchestratorProvider);

  Future<void> start() async {
    _lastError = null;
    _lastWarning = null;
    var settings = ref.read(appSettingsControllerProvider);

    // Obstacle detection modes require audio announcements for user safety.
    // If set to vibration-only, automatically enable audio & vibration.
    if (settings.feedbackSettings.mode == FeedbackMode.vibration) {
      ref
          .read(appSettingsControllerProvider.notifier)
          .selectFeedbackMode(FeedbackMode.audioAndVibration);
      ref
          .read(appSettingsControllerProvider.notifier)
          .setVibrationEnabled(true);
      settings = ref.read(appSettingsControllerProvider);
      updateSettings();
    }

    final tts = ref.read(ttsServiceProvider);
    try {
      await tts.initialize();
    } catch (error) {
      final vibrationFallback =
          settings.vibrationEnabled &&
          settings.feedbackSettings.mode == FeedbackMode.audioAndVibration;
      if (!vibrationFallback) rethrow;
      _lastWarning =
          'Speech is unavailable; vibration feedback remains active. '
          '${_safeErrorMessage(error)}';
    }
    _running = true;
    state = true;
  }

  Future<void> stop() async {
    _running = false;
    state = false;
    await _orchestrator.stop();
  }

  void updateSettings() {
    final settings = ref.read(appSettingsControllerProvider);
    final orchestrator = _orchestrator;
    if (orchestrator is FeedbackAlertOrchestrator) {
      orchestrator.cooldownSeconds =
          settings.feedbackSettings.announcementCooldownSeconds;
      orchestrator.vibrationEnabled = settings.vibrationEnabled;
      orchestrator.feedbackMode = settings.feedbackSettings.mode;
    }
  }

  Future<void> _processAlerts() async {
    if (!_running) return;
    // Suppress obstacle detection alerts while the voice assistant is interacting with the user
    final assistantSession = ref
        .read(assistantSessionControllerProvider)
        .sessionState;
    if (assistantSession.isActive ||
        assistantSession == AssistantSessionState.speaking ||
        assistantSession == AssistantSessionState.awaitingConfirmation) {
      return;
    }
    final alerts = ref.read(obstacleAlertsProvider);
    try {
      await _orchestrator.processAlerts(alerts);
      final orchestrator = _orchestrator;
      if (orchestrator is FeedbackAlertOrchestrator) {
        _lastWarning = orchestrator.lastWarning ?? _lastWarning;
      }
    } catch (error) {
      _lastError = _safeErrorMessage(error);
      _running = false;
      state = false;
    }
  }

  void _cleanup() {
    _running = false;
  }

  String _safeErrorMessage(Object error) {
    final message = error.toString();
    return message.length <= 120 ? message : message.substring(0, 120);
  }
}
