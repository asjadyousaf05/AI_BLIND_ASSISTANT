import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/app_failure.dart';
import '../../core/result/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/detection_settings.dart';
import '../../domain/entities/feedback_settings.dart';
import '../../domain/enums/detection_environment_mode.dart';
import '../../domain/enums/detection_sensitivity.dart';
import '../../domain/enums/feedback_mode.dart';
import '../../domain/enums/operating_mode.dart';
import '../../domain/repositories/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository([this._prefs]);

  SharedPreferences? _prefs;

  static const _keyOperatingMode = 'settings_operating_mode';
  static const _keyFeedbackMode = 'settings_feedback_mode';
  static const _keyCooldown = 'settings_announcement_cooldown';
  static const _keySensitivity = 'settings_detection_sensitivity';
  static const _keyConfidence = 'settings_minimum_confidence';
  static const _keyVibration = 'settings_vibration_enabled';
  static const _keyHighContrast = 'settings_high_contrast';
  static const _keyLargeText = 'settings_large_text';
  static const _keyReducedMotion = 'settings_reduced_motion';
  static const _keyHandsFreeAssistant = 'settings_hands_free_assistant';
  static const _keyEnvironmentMode = 'settings_environment_mode';

  static const int _minCooldown = 1;
  static const int _maxCooldown = 30;
  static const double _minConfidence = 0.1;
  static const double _maxConfidence = 1.0;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<Result<AppSettings>> loadSettings() async {
    try {
      final prefs = await _preferences;
      return Success(_readSettings(prefs));
    } catch (e) {
      return const Success(AppSettings.defaults);
    }
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    try {
      final prefs = await _preferences;

      await prefs.setString(
        _keyOperatingMode,
        settings.preferredOperatingMode.name,
      );
      await prefs.setString(
        _keyFeedbackMode,
        settings.feedbackSettings.mode.name,
      );
      await prefs.setInt(
        _keyCooldown,
        _clampCooldown(settings.feedbackSettings.announcementCooldownSeconds),
      );
      await prefs.setString(
        _keySensitivity,
        settings.detectionSettings.sensitivity.name,
      );
      await prefs.setDouble(
        _keyConfidence,
        _clampConfidence(settings.detectionSettings.minimumConfidence),
      );
      await prefs.setBool(_keyVibration, settings.vibrationEnabled);
      await prefs.setBool(_keyHighContrast, settings.highContrastEnabled);
      await prefs.setBool(_keyLargeText, settings.largeTextEnabled);
      await prefs.setBool(_keyReducedMotion, settings.reducedMotionEnabled);
      await prefs.setBool(
        _keyHandsFreeAssistant,
        settings.handsFreeAssistantEnabled,
      );
      await prefs.setString(_keyEnvironmentMode, settings.environmentMode.name);

      return const Success(null);
    } catch (e) {
      return Failure(StorageFailure(logMessage: 'Failed to save settings: $e'));
    }
  }

  AppSettings _readSettings(SharedPreferences prefs) {
    return AppSettings(
      preferredOperatingMode: _parseEnum(
        prefs.getString(_keyOperatingMode),
        OperatingMode.values,
        OperatingMode.mobile,
      ),
      feedbackSettings: FeedbackSettings(
        mode: _parseEnum(
          prefs.getString(_keyFeedbackMode),
          FeedbackMode.values,
          FeedbackMode.audioAndVibration,
        ),
        announcementCooldownSeconds: _clampCooldown(
          prefs.getInt(_keyCooldown) ??
              FeedbackSettings.defaults.announcementCooldownSeconds,
        ),
      ),
      detectionSettings: DetectionSettings(
        sensitivity: _parseEnum(
          prefs.getString(_keySensitivity),
          DetectionSensitivity.values,
          DetectionSensitivity.medium,
        ),
        minimumConfidence: _clampConfidence(
          prefs.getDouble(_keyConfidence) ??
              DetectionSettings.defaults.minimumConfidence,
        ),
      ),
      vibrationEnabled: prefs.getBool(_keyVibration) ?? true,
      highContrastEnabled: prefs.getBool(_keyHighContrast) ?? false,
      largeTextEnabled: prefs.getBool(_keyLargeText) ?? false,
      reducedMotionEnabled: prefs.getBool(_keyReducedMotion) ?? false,
      handsFreeAssistantEnabled: prefs.getBool(_keyHandsFreeAssistant) ?? true,
      environmentMode: _parseEnum(
        prefs.getString(_keyEnvironmentMode),
        DetectionEnvironmentMode.values,
        DetectionEnvironmentMode.indoor,
      ),
    );
  }

  T _parseEnum<T extends Enum>(String? value, List<T> values, T fallback) {
    if (value == null) return fallback;
    try {
      return values.firstWhere((e) => e.name == value);
    } catch (_) {
      return fallback;
    }
  }

  int _clampCooldown(int value) => value.clamp(_minCooldown, _maxCooldown);

  double _clampConfidence(double value) =>
      value.clamp(_minConfidence, _maxConfidence);
}
