/// Authoritative states for the Assistant Audio State Machine.
enum AssistantAudioState {
  /// Assistant is idle, waiting for commands or page changes.
  idle,

  /// Document Scanner camera is active and ready to frame/capture.
  scannerReady,

  /// Document Scanner is actively reading sentences aloud.
  scannerReading,

  /// User spoke the wake phrase ("Vision") while reading; speech is paused and ASR is armed.
  bargeInArmed,

  /// Short command capture window is open for scanner reader commands.
  commandCapture,

  /// Document reader is paused at a specific sentence.
  scannerPaused,

  /// Document reading was stopped/silenced.
  scannerStopped,

  /// Camera is capturing a high-resolution photo.
  scanning,

  /// ML Kit OCR neural engine is processing the image.
  ocrProcessing,

  /// Application has been sent to the background; audio resources released.
  appBackground,

  /// An error occurred during audio or camera operation.
  error,
}

extension AssistantAudioStateX on AssistantAudioState {
  /// Whether the document scanner is in an active reading session.
  bool get isReadingSession =>
      this == AssistantAudioState.scannerReading ||
      this == AssistantAudioState.bargeInArmed ||
      this == AssistantAudioState.commandCapture ||
      this == AssistantAudioState.scannerPaused;

  /// Whether TTS audio is actively emitting sound.
  bool get isSpeaking => this == AssistantAudioState.scannerReading;

  /// Human-readable label for accessibility live region announcements.
  String get accessibilityLabel => switch (this) {
    AssistantAudioState.idle => 'Assistant ready',
    AssistantAudioState.scannerReady => 'Scanner ready',
    AssistantAudioState.scannerReading => 'Reading document',
    AssistantAudioState.bargeInArmed => 'Listening for command',
    AssistantAudioState.commandCapture => 'Listening for command',
    AssistantAudioState.scannerPaused => 'Reading paused',
    AssistantAudioState.scannerStopped => 'Reading stopped',
    AssistantAudioState.scanning => 'Capturing document photo',
    AssistantAudioState.ocrProcessing => 'Extracting text with AI',
    AssistantAudioState.appBackground => 'App paused',
    AssistantAudioState.error => 'Error',
  };
}
