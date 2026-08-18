import '../enums/voice_feature_context.dart';
import '../enums/voice_intent.dart';

/// Metadata for a voice-controllable action registered in the voice action
/// registry.
///
/// Each entry defines the canonical name, allowed contexts, and execution
/// policies for one [VoiceIntent] type.
class VoiceActionDefinition {
  const VoiceActionDefinition({
    required this.intentType,
    required this.canonicalName,
    required this.allowedContexts,
    this.forbiddenContexts = const {},
    this.requiresConfirmation = false,
    this.isEmergency = false,
    this.interruptsTts = false,
    this.interruptsDetection = false,
    this.feedbackText,
  });

  /// The runtime type of the [VoiceIntent] this definition applies to.
  final Type intentType;

  /// Human-readable canonical name (for diagnostics / logs).
  final String canonicalName;

  /// Feature contexts where this action is allowed. Empty means all contexts.
  final Set<VoiceFeatureContext> allowedContexts;

  /// Feature contexts where this action is explicitly forbidden.
  final Set<VoiceFeatureContext> forbiddenContexts;

  /// Whether the user must confirm before execution.
  final bool requiresConfirmation;

  /// Emergency commands bypass most authorization checks.
  final bool isEmergency;

  /// Whether executing this command should stop active TTS.
  final bool interruptsTts;

  /// Whether executing this command should stop active detection.
  final bool interruptsDetection;

  /// Default feedback text after successful execution.
  final String? feedbackText;

  /// Whether this action is allowed in the given [context].
  bool isAllowedIn(VoiceFeatureContext context) {
    if (isEmergency) return true;
    if (forbiddenContexts.contains(context)) return false;
    if (allowedContexts.isEmpty) return true;
    return allowedContexts.contains(context);
  }
}
