import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/feedback_mode.dart';
import '../domain/services/alert_orchestrator.dart';
import '../domain/services/tts_service.dart';
import '../domain/services/vibration_service.dart';
import '../infrastructure/feedback/device_vibration_service.dart';
import '../infrastructure/feedback/feedback_alert_orchestrator.dart';
import '../infrastructure/feedback/flutter_tts_service.dart';
import 'providers.dart';
import 'risk_providers.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = FlutterTtsService();
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
    final settings = ref.read(appSettingsControllerProvider);
    final audioRequested =
        settings.feedbackSettings.mode != FeedbackMode.vibration;
    final vibrationRequested =
        settings.vibrationEnabled &&
        settings.feedbackSettings.mode != FeedbackMode.audio;
    if (!audioRequested && !vibrationRequested) {
      throw StateError(
        'Vibration-only feedback is disabled in Settings. '
        'Enable vibration or select audio feedback.',
      );
    }
    if (settings.feedbackSettings.mode != FeedbackMode.vibration) {
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
