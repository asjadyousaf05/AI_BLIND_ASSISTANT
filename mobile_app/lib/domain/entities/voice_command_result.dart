/// The outcome of executing a voice command.
///
/// Every command execution produces exactly one [VoiceCommandResult].
/// The kernel uses this to decide what feedback to give the user.
sealed class VoiceCommandResult {
  const VoiceCommandResult();
}

/// The command executed successfully.
class VoiceCommandSuccess extends VoiceCommandResult {
  final String? feedbackText;
  final Map<String, dynamic> data;

  const VoiceCommandSuccess({this.feedbackText, this.data = const {}});
}

/// The system is already in the requested state.
class VoiceCommandAlreadyInState extends VoiceCommandResult {
  final String message;
  const VoiceCommandAlreadyInState(this.message);
}

/// The feature is unavailable (e.g. no camera, no model).
class VoiceCommandUnavailable extends VoiceCommandResult {
  final String reason;
  const VoiceCommandUnavailable(this.reason);
}

/// A permission is required before this action can execute.
class VoiceCommandPermissionRequired extends VoiceCommandResult {
  final String permission;
  const VoiceCommandPermissionRequired(this.permission);
}

/// The current state does not allow this action.
class VoiceCommandInvalidState extends VoiceCommandResult {
  final String reason;
  const VoiceCommandInvalidState(this.reason);
}

/// The command requires user confirmation before executing.
class VoiceCommandNeedsConfirmation extends VoiceCommandResult {
  final String prompt;
  const VoiceCommandNeedsConfirmation(this.prompt);
}

/// The command failed to execute.
class VoiceCommandFailure extends VoiceCommandResult {
  final String message;
  const VoiceCommandFailure(this.message);
}
