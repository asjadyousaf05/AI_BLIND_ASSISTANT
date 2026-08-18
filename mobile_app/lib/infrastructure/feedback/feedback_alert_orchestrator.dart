import '../../domain/entities/obstacle_alert.dart';
import '../../domain/enums/feedback_mode.dart';
import '../../domain/enums/risk_level.dart';
import '../../domain/enums/screen_position.dart';
import '../../domain/services/alert_orchestrator.dart';
import '../../domain/services/tts_service.dart';
import '../../domain/services/vibration_service.dart';

class FeedbackAlertOrchestrator implements AlertOrchestrator {
  FeedbackAlertOrchestrator({
    required TtsService ttsService,
    required VibrationService vibrationService,
    this.cooldownSeconds = 3,
    this.vibrationEnabled = true,
    this.feedbackMode = FeedbackMode.audioAndVibration,
    this.minimumAnnouncementInterval = const Duration(milliseconds: 1200),
  }) : _tts = ttsService,
       _vibration = vibrationService;

  final TtsService _tts;
  final VibrationService _vibration;

  int cooldownSeconds;
  bool vibrationEnabled;
  FeedbackMode feedbackMode;
  final Duration minimumAnnouncementInterval;
  bool _active = false;
  bool _processing = false;
  String? lastWarning;

  final Map<String, DateTime> _lastAnnouncedTimes = {};
  RiskLevel? _lastAnnouncedRisk;
  DateTime? _lastAnnouncementTime;
  String? _lastSignature;

  @override
  bool get isActive => _active;

  bool get _audioEnabled =>
      feedbackMode == FeedbackMode.audio ||
      feedbackMode == FeedbackMode.audioAndVibration;

  bool get _vibrationAllowed =>
      vibrationEnabled &&
      (feedbackMode == FeedbackMode.vibration ||
          feedbackMode == FeedbackMode.audioAndVibration);

  @override
  Future<void> processAlerts(List<ObstacleAlert> alerts) async {
    if (alerts.isEmpty || _processing) return;
    final usefulAlerts = alerts.where((alert) => alert.riskLevel.requiresAlert);
    if (usefulAlerts.isEmpty) return;
    _active = true;
    _processing = true;

    try {
      // RiskAssessor supplies alerts in priority order. Announce at most one.
      final topAlert = usefulAlerts.first;

      if (!_shouldAnnounce(topAlert)) return;

      final shouldInterrupt =
          _lastAnnouncedRisk != null &&
          topAlert.riskLevel.priority > _lastAnnouncedRisk!.priority;

      // Record before awaiting platform services so another frame cannot race
      // through the cooldown while speech or haptics are starting.
      _recordAnnouncement(topAlert);

      final failures = <String>[];
      var successfulOutputs = 0;

      if (_vibrationAllowed) {
        try {
          await _vibration.vibrateForRisk(topAlert.riskLevel);
          successfulOutputs++;
        } catch (error) {
          failures.add('vibration: ${_safeErrorMessage(error)}');
        }
      }

      if (_audioEnabled) {
        try {
          final pan = switch (topAlert.position) {
            ScreenPosition.left => -0.85,
            ScreenPosition.centerLeft => -0.45,
            ScreenPosition.center => 0.0,
            ScreenPosition.centerRight => 0.45,
            ScreenPosition.right => 0.85,
          };
          await _tts.speak(
            topAlert.spokenDescription,
            interrupt: shouldInterrupt,
            pan: pan,
          );
          successfulOutputs++;
        } catch (error) {
          failures.add('speech: ${_safeErrorMessage(error)}');
        }
      }
      if (failures.isNotEmpty) {
        final detail = 'Feedback failed: ${failures.join('; ')}';
        if (successfulOutputs == 0) throw StateError(detail);
        lastWarning =
            '$detail; the other selected feedback mode remains active.';
      } else {
        lastWarning = null;
      }
    } finally {
      _processing = false;
    }
  }

  bool _shouldAnnounce(ObstacleAlert alert) {
    final now = DateTime.now();
    final urgentUpgrade =
        alert.riskLevel == RiskLevel.critical &&
        _lastAnnouncedRisk != RiskLevel.critical;
    if (!urgentUpgrade &&
        _lastAnnouncementTime != null &&
        now.difference(_lastAnnouncementTime!) < minimumAnnouncementInterval) {
      return false;
    }

    final signature = _signature(alert);
    final key = _cooldownKey(alert);
    final lastTime = _lastAnnouncedTimes[key];

    if (lastTime == null) return signature != _lastSignature || urgentUpgrade;

    final elapsed = now.difference(lastTime);
    if (elapsed.inSeconds >= cooldownSeconds) return true;

    return urgentUpgrade;
  }

  String _cooldownKey(ObstacleAlert alert) {
    return alert.detection.label;
  }

  String _signature(ObstacleAlert alert) {
    return '${alert.detection.label}_${alert.position.name}_${alert.riskLevel.name}';
  }

  void _recordAnnouncement(ObstacleAlert alert) {
    final key = _cooldownKey(alert);
    final now = DateTime.now();
    _lastAnnouncedTimes[key] = now;
    _lastAnnouncementTime = now;
    _lastAnnouncedRisk = alert.riskLevel;
    _lastSignature = _signature(alert);
  }

  @override
  Future<void> stop() async {
    _active = false;
    final failures = <String>[];
    try {
      await _tts.stop();
    } catch (error) {
      failures.add('speech: ${_safeErrorMessage(error)}');
    }
    try {
      await _vibration.cancel();
    } catch (error) {
      failures.add('vibration: ${_safeErrorMessage(error)}');
    }
    _lastAnnouncedTimes.clear();
    _lastAnnouncedRisk = null;
    _lastAnnouncementTime = null;
    _lastSignature = null;
    lastWarning = null;
    _processing = false;
    if (failures.isNotEmpty) {
      throw StateError('Feedback cleanup failed: ${failures.join('; ')}');
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _tts.dispose();
  }

  String _safeErrorMessage(Object error) {
    final message = error.toString();
    return message.length <= 120 ? message : message.substring(0, 120);
  }
}
