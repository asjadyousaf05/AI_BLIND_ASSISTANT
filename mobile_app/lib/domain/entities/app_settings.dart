import '../enums/operating_mode.dart';
import 'detection_settings.dart';
import 'feedback_settings.dart';

class AppSettings {
  const AppSettings({
    required this.preferredOperatingMode,
    required this.feedbackSettings,
    required this.detectionSettings,
    required this.vibrationEnabled,
    required this.highContrastEnabled,
    required this.largeTextEnabled,
    required this.reducedMotionEnabled,
  });

  static const defaults = AppSettings(
    preferredOperatingMode: OperatingMode.mobile,
    feedbackSettings: FeedbackSettings.defaults,
    detectionSettings: DetectionSettings.defaults,
    vibrationEnabled: true,
    highContrastEnabled: false,
    largeTextEnabled: false,
    reducedMotionEnabled: false,
  );

  final OperatingMode preferredOperatingMode;
  final FeedbackSettings feedbackSettings;
  final DetectionSettings detectionSettings;
  final bool vibrationEnabled;
  final bool highContrastEnabled;
  final bool largeTextEnabled;
  final bool reducedMotionEnabled;

  AppSettings copyWith({
    OperatingMode? preferredOperatingMode,
    FeedbackSettings? feedbackSettings,
    DetectionSettings? detectionSettings,
    bool? vibrationEnabled,
    bool? highContrastEnabled,
    bool? largeTextEnabled,
    bool? reducedMotionEnabled,
  }) {
    return AppSettings(
      preferredOperatingMode:
          preferredOperatingMode ?? this.preferredOperatingMode,
      feedbackSettings: feedbackSettings ?? this.feedbackSettings,
      detectionSettings: detectionSettings ?? this.detectionSettings,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      largeTextEnabled: largeTextEnabled ?? this.largeTextEnabled,
      reducedMotionEnabled: reducedMotionEnabled ?? this.reducedMotionEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredOperatingMode': preferredOperatingMode.name,
      'feedbackMode': feedbackSettings.mode.name,
      'announcementCooldownSeconds':
          feedbackSettings.announcementCooldownSeconds,
      'detectionSensitivity': detectionSettings.sensitivity.name,
      'minimumConfidence': detectionSettings.minimumConfidence,
      'vibrationEnabled': vibrationEnabled,
      'highContrastEnabled': highContrastEnabled,
      'largeTextEnabled': largeTextEnabled,
      'reducedMotionEnabled': reducedMotionEnabled,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.preferredOperatingMode == preferredOperatingMode &&
        other.feedbackSettings == feedbackSettings &&
        other.detectionSettings == detectionSettings &&
        other.vibrationEnabled == vibrationEnabled &&
        other.highContrastEnabled == highContrastEnabled &&
        other.largeTextEnabled == largeTextEnabled &&
        other.reducedMotionEnabled == reducedMotionEnabled;
  }

  @override
  int get hashCode => Object.hash(
    preferredOperatingMode,
    feedbackSettings,
    detectionSettings,
    vibrationEnabled,
    highContrastEnabled,
    largeTextEnabled,
    reducedMotionEnabled,
  );
}
