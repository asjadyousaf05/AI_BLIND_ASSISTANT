enum FeedbackMode {
  audio,
  vibration,
  audioAndVibration;

  String get label => switch (this) {
    FeedbackMode.audio => 'Audio',
    FeedbackMode.vibration => 'Vibration',
    FeedbackMode.audioAndVibration => 'Audio and vibration',
  };
}
