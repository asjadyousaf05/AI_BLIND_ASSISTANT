/// Authoritative runtime states for VisionVoiceKernelV3.
///
/// State transitions are enforced by the kernel. Callers read the current
/// state but cannot set it directly.
enum VoiceRuntimeState {
  /// Voice kernel is off. No recognizer running.
  disabled,

  /// Model loading or recognizer creation in progress.
  initializing,

  /// Passively listening for the wake phrase (hands-free mode).
  wakeListening,

  /// Actively listening for a spoken command after wake.
  commandListening,

  /// A recognized command is being resolved and executed.
  executing,

  /// TTS is speaking a response or feedback.
  speaking,

  /// Listening for barge-in interruptions while TTS is active.
  bargeInListening,

  /// Recognizer paused (e.g. app backgrounded or phone call).
  suspended,

  /// Recovering from a transient error (e.g. AudioRecord release → reacquire).
  recovering,

  /// A non-transient error occurred. Manual restart may be needed.
  error,
}

extension VoiceRuntimeStateX on VoiceRuntimeState {
  /// Whether the recognizer is actively capturing microphone audio.
  bool get isListening =>
      this == VoiceRuntimeState.wakeListening ||
      this == VoiceRuntimeState.commandListening ||
      this == VoiceRuntimeState.bargeInListening;

  /// Whether the kernel is in a state that accepts new voice input.
  bool get acceptsVoiceInput =>
      this == VoiceRuntimeState.commandListening ||
      this == VoiceRuntimeState.bargeInListening;

  /// Whether the kernel is operational (not disabled/error).
  bool get isOperational =>
      this != VoiceRuntimeState.disabled &&
      this != VoiceRuntimeState.error;

  /// Human-readable label for diagnostics and accessibility.
  String get label => switch (this) {
    VoiceRuntimeState.disabled => 'Voice assistant is off',
    VoiceRuntimeState.initializing => 'Starting voice assistant',
    VoiceRuntimeState.wakeListening => 'Listening for wake word',
    VoiceRuntimeState.commandListening => 'Listening for command',
    VoiceRuntimeState.executing => 'Running command',
    VoiceRuntimeState.speaking => 'Speaking',
    VoiceRuntimeState.bargeInListening => 'Listening while speaking',
    VoiceRuntimeState.suspended => 'Voice assistant paused',
    VoiceRuntimeState.recovering => 'Reconnecting microphone',
    VoiceRuntimeState.error => 'Voice assistant error',
  };
}
