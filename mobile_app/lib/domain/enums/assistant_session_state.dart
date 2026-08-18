/// Voice assistant session states.
///
/// Every state must have a truthful, accessible description so TalkBack
/// and TTS can announce the current condition to the user.
enum AssistantSessionState {
  /// No assistant session is in progress.
  idle,

  /// Verifying that the laptop backend is reachable.
  checkingConnection,

  /// Requesting Android RECORD_AUDIO permission.
  requestingPermission,

  /// Verifying that Android has a dedicated on-device speech service.
  checkingVoiceAvailability,

  /// Microphone is open and capturing audio.
  listening,

  /// The dedicated phone service is finalizing an offline transcript.
  processingAudio,

  /// Resolving a local command or waiting for a conversational response.
  thinking,

  /// Model proposed a sensitive action; waiting for user confirmation.
  awaitingConfirmation,

  /// Confirmed action is being executed by the app service.
  executingAction,

  /// Response is being read aloud by Android TTS.
  speaking,

  /// Session completed successfully.
  completed,

  /// Session was cancelled by the user.
  cancelled,

  /// Laptop backend is unreachable. Offline assistance remains active.
  laptopUnavailable,

  /// Authentication failed (invalid pairing, expired token).
  authenticationFailed,

  /// Backend protocol version is incompatible with this app version.
  incompatible,

  /// Request timed out.
  timeout,

  /// Unrecoverable error.
  error;

  /// Returns the label shown in the UI and announced by TTS.
  String get label => switch (this) {
    AssistantSessionState.idle => 'Ready',
    AssistantSessionState.checkingConnection => 'Checking connection',
    AssistantSessionState.requestingPermission => 'Requesting microphone',
    AssistantSessionState.checkingVoiceAvailability =>
      'Checking offline speech',
    AssistantSessionState.listening => 'Listening',
    AssistantSessionState.processingAudio => 'Recognizing offline speech',
    AssistantSessionState.thinking => 'Understanding request',
    AssistantSessionState.awaitingConfirmation => 'Confirmation required',
    AssistantSessionState.executingAction => 'Executing action',
    AssistantSessionState.speaking => 'Speaking',
    AssistantSessionState.completed => 'Done',
    AssistantSessionState.cancelled => 'Cancelled',
    AssistantSessionState.laptopUnavailable => 'Laptop unavailable',
    AssistantSessionState.authenticationFailed => 'Authentication failed',
    AssistantSessionState.incompatible => 'Incompatible version',
    AssistantSessionState.timeout => 'Request timed out',
    AssistantSessionState.error => 'Error',
  };

  /// Spoken announcement made when entering this state.
  String get announcement => switch (this) {
    AssistantSessionState.idle => '',
    AssistantSessionState.checkingConnection => 'Checking connection.',
    AssistantSessionState.requestingPermission =>
      'Requesting microphone permission.',
    AssistantSessionState.checkingVoiceAvailability =>
      'Checking offline speech recognition.',
    AssistantSessionState.listening => 'Listening.',
    AssistantSessionState.processingAudio =>
      'Recognizing your speech on this phone.',
    AssistantSessionState.thinking => 'Understanding your request.',
    AssistantSessionState.awaitingConfirmation => 'Confirmation required.',
    AssistantSessionState.executingAction => 'Executing action.',
    AssistantSessionState.speaking => '',
    AssistantSessionState.completed => '',
    AssistantSessionState.cancelled => 'Cancelled.',
    AssistantSessionState.laptopUnavailable =>
      'The personal assistant is unavailable. '
          'Offline assistance remains active.',
    AssistantSessionState.authenticationFailed =>
      'Authentication failed. Please re-pair the assistant.',
    AssistantSessionState.incompatible =>
      'Incompatible backend version. Please update the app or backend.',
    AssistantSessionState.timeout => 'Request timed out. Please try again.',
    AssistantSessionState.error => 'An error occurred. Please try again.',
  };

  bool get isTerminal => switch (this) {
    AssistantSessionState.idle ||
    AssistantSessionState.completed ||
    AssistantSessionState.cancelled ||
    AssistantSessionState.laptopUnavailable ||
    AssistantSessionState.authenticationFailed ||
    AssistantSessionState.incompatible ||
    AssistantSessionState.timeout ||
    AssistantSessionState.error => true,
    _ => false,
  };

  bool get isActive => switch (this) {
    AssistantSessionState.listening ||
    AssistantSessionState.checkingVoiceAvailability ||
    AssistantSessionState.processingAudio ||
    AssistantSessionState.thinking ||
    AssistantSessionState.executingAction => true,
    _ => false,
  };

  bool get canStartNewSession => switch (this) {
    AssistantSessionState.idle ||
    AssistantSessionState.completed ||
    AssistantSessionState.cancelled ||
    AssistantSessionState.laptopUnavailable ||
    AssistantSessionState.timeout ||
    AssistantSessionState.error => true,
    _ => false,
  };
}
