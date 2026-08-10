import '../enums/feedback_mode.dart';

class FeedbackSettings {
  const FeedbackSettings({
    required this.mode,
    required this.announcementCooldownSeconds,
  });

  static const defaults = FeedbackSettings(
    mode: FeedbackMode.audioAndVibration,
    announcementCooldownSeconds: 5,
  );

  final FeedbackMode mode;
  final int announcementCooldownSeconds;

  bool get audioEnabled =>
      mode == FeedbackMode.audio || mode == FeedbackMode.audioAndVibration;

  bool get vibrationEnabled =>
      mode == FeedbackMode.vibration || mode == FeedbackMode.audioAndVibration;

  FeedbackSettings copyWith({
    FeedbackMode? mode,
    int? announcementCooldownSeconds,
  }) {
    return FeedbackSettings(
      mode: mode ?? this.mode,
      announcementCooldownSeconds:
          announcementCooldownSeconds ?? this.announcementCooldownSeconds,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedbackSettings &&
        other.mode == mode &&
        other.announcementCooldownSeconds == announcementCooldownSeconds;
  }

  @override
  int get hashCode => Object.hash(mode, announcementCooldownSeconds);
}
