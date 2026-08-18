/// Classifies the kind of assistant failure for accessible recovery guidance.
enum AssistantFailureKind {
  /// Microphone permission denied by the user.
  microphonePermissionDenied,

  /// Microphone permission permanently denied; user must open settings.
  microphonePermissionPermanentlyDenied,

  /// Neither the dedicated Android service nor bundled recognizer can start.
  onDeviceSpeechUnavailable,

  /// The laptop backend could not be reached.
  backendUnreachable,

  /// Authentication or pairing token was rejected.
  authenticationFailed,

  /// Backend protocol version is incompatible.
  incompatibleVersion,

  /// Audio recording failed (hardware or OS error).
  audioRecordingFailed,

  /// The recorded audio clip was empty or silent.
  emptyAudio,

  /// The audio payload exceeded the maximum allowed size.
  audioTooLarge,

  /// Speech-to-text transcription failed.
  transcriptionFailed,

  /// The AI model returned an error or unparsable output.
  modelError,

  /// Proposed tool action was rejected (unknown tool, bad arguments).
  toolRejected,

  /// The action execution was not confirmed by the user.
  actionNotConfirmed,

  /// The action timed out before completion.
  actionTimeout,

  /// An unexpected error occurred.
  unexpected;

  /// Accessible recovery hint shown to the user.
  String get recoveryHint => switch (this) {
    AssistantFailureKind.microphonePermissionDenied =>
      'Microphone permission is required for voice input. '
          'Tap the button to request permission, or use text input.',
    AssistantFailureKind.microphonePermissionPermanentlyDenied =>
      'Microphone permission was permanently denied. '
          'Open device settings to allow microphone access, '
          'or use text input.',
    AssistantFailureKind.onDeviceSpeechUnavailable =>
      'Offline voice recognition could not start. Restart the app and try '
          'again, or use typed app controls. App-command audio is never sent '
          'to a laptop or cloud.',
    AssistantFailureKind.backendUnreachable =>
      'The laptop assistant is unavailable. '
          'Ensure the laptop is on the same Wi-Fi network and '
          'the backend is running. Offline assistance remains active.',
    AssistantFailureKind.authenticationFailed =>
      'Authentication failed. Please re-pair the assistant '
          'using the connection screen.',
    AssistantFailureKind.incompatibleVersion =>
      'The backend version is incompatible. '
          'Please update the app or the laptop backend.',
    AssistantFailureKind.audioRecordingFailed =>
      'Audio recording failed. Please check microphone access and try again.',
    AssistantFailureKind.emptyAudio =>
      'No speech was detected. Please hold the button and speak clearly.',
    AssistantFailureKind.audioTooLarge =>
      'Recording was too long. Please keep requests under 30 seconds.',
    AssistantFailureKind.transcriptionFailed =>
      'The phone could not understand your speech offline. Please try again.',
    AssistantFailureKind.modelError =>
      'The AI model encountered an error. Please try again.',
    AssistantFailureKind.toolRejected =>
      'The requested action could not be performed.',
    AssistantFailureKind.actionNotConfirmed => 'Action cancelled.',
    AssistantFailureKind.actionTimeout =>
      'The action timed out. Please try again.',
    AssistantFailureKind.unexpected => 'An unexpected error occurred.',
  };
}
