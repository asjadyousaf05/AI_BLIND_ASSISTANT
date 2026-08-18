/// Reasons a voice command can be rejected before execution.
///
/// Every rejection is logged with its reason for diagnostics. The kernel
/// uses these to provide appropriate user feedback when a command is not
/// executed.
enum VoiceRejectionReason {
  /// The recognition event came from a previous recognizer session.
  staleSession,

  /// The recognition event is older than the command timeout window.
  expired,

  /// This recognition ID was already consumed and executed.
  duplicate,

  /// The command targets a feature context that is not currently active.
  wrongContext,

  /// The command is not permitted in the current runtime state.
  actionNotAllowed,

  /// Multiple intents matched with similar confidence.
  ambiguous,

  /// The best match score is below the minimum acceptance threshold.
  lowMatch,

  /// The recognized text matches active TTS output (speaker echo).
  selfTtsEcho,

  /// A partial result was recognized but is not executable without final.
  partialNotExecutable,

  /// The voice kernel is suspended (e.g. app backgrounded).
  assistantSuspended,

  /// The requested action is already running / in desired state.
  actionAlreadyRunning,

  /// Circuit breaker tripped — same command fired too many times.
  commandLoopSuppressed,

  /// The recognized text is empty, [unk], or nonsensical.
  emptyOrNonsense,
}

extension VoiceRejectionReasonX on VoiceRejectionReason {
  /// Whether this rejection should be silently discarded (no user feedback).
  ///
  /// Rejections are silent by default to prevent ambient noise, unprompted background
  /// speech, and wrong-context chatter from triggering disruptive error announcements.
  bool get isSilent => switch (this) {
    VoiceRejectionReason.actionNotAllowed => false,
    _ => true,
  };

  /// User-facing message for non-silent rejections or intentional retries.
  String get userMessage => switch (this) {
    VoiceRejectionReason.wrongContext =>
      'That command is not available on this screen.',
    VoiceRejectionReason.actionNotAllowed =>
      'That action is not allowed right now.',
    VoiceRejectionReason.ambiguous =>
      'Please be more specific.',
    VoiceRejectionReason.lowMatch =>
      'Please repeat.',
    VoiceRejectionReason.assistantSuspended =>
      'The voice assistant is paused.',
    _ => '',
  };
}
