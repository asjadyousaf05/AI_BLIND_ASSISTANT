/// The active user-facing feature context.
///
/// Set by each screen on enter and cleared on exit. Used by the voice kernel
/// to authorize commands (e.g. scanner-only commands are rejected when the
/// user is on the home screen).
enum VoiceFeatureContext {
  /// Home / mode-selection screen.
  home,

  /// Mobile Detection (camera object detection) is active.
  mobileDetection,

  /// Document Scanner — camera capture phase.
  scannerCapture,

  /// Document Scanner — reading text aloud.
  scannerReading,

  /// Settings screen.
  settings,

  /// Smart AI / assistant chat screen.
  smartAi,

  /// Raspberry Pi wearable screen.
  wearable,

  /// Help / safety / about screens.
  informational,

  /// No specific feature context (e.g. startup, transition).
  unknown,
}

extension VoiceFeatureContextX on VoiceFeatureContext {
  /// Whether this context involves active camera use.
  bool get usesCamera =>
      this == VoiceFeatureContext.mobileDetection ||
      this == VoiceFeatureContext.scannerCapture;

  /// Whether this context involves audio playback (TTS / reading).
  bool get hasAudioPlayback =>
      this == VoiceFeatureContext.scannerReading ||
      this == VoiceFeatureContext.smartAi;

  /// Whether the user is in the document scanner flow.
  bool get isScanner =>
      this == VoiceFeatureContext.scannerCapture ||
      this == VoiceFeatureContext.scannerReading;

  /// Human-readable label for diagnostics.
  String get label => switch (this) {
    VoiceFeatureContext.home => 'Home',
    VoiceFeatureContext.mobileDetection => 'Mobile Detection',
    VoiceFeatureContext.scannerCapture => 'Document Scanner',
    VoiceFeatureContext.scannerReading => 'Document Reading',
    VoiceFeatureContext.settings => 'Settings',
    VoiceFeatureContext.smartAi => 'Smart AI',
    VoiceFeatureContext.wearable => 'Wearable',
    VoiceFeatureContext.informational => 'Info',
    VoiceFeatureContext.unknown => 'Unknown',
  };
}
