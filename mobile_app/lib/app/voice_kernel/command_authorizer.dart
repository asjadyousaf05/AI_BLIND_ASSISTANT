import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_recognition_event.dart';
import '../../domain/enums/voice_feature_context.dart';
import '../../domain/enums/voice_intent.dart';
import '../../domain/enums/voice_rejection_reason.dart';
import '../../domain/services/tts_echo_guard.dart';
import '../../domain/services/voice_action_registry.dart';
import 'command_circuit_breaker.dart';
import 'command_deduplicator.dart';

/// Result of the command authorization pipeline.
class AuthorizationResult {
  const AuthorizationResult.allowed() : rejection = null;
  const AuthorizationResult.rejected(this.rejection);

  final VoiceRejectionReason? rejection;
  bool get isAllowed => rejection == null;
}

/// Pipeline gate that validates a voice command before execution.
///
/// Checks are performed in priority order. The first failing check
/// produces the rejection reason.
class CommandAuthorizer {
  CommandAuthorizer({
    required this.deduplicator,
    required this.circuitBreaker,
    required this.ttsEchoGuard,
  });

  final CommandDeduplicator deduplicator;
  final CommandCircuitBreaker circuitBreaker;
  final TtsEchoGuard ttsEchoGuard;

  /// Authorizes a command for execution.
  ///
  /// Returns [AuthorizationResult.allowed] if the command should execute,
  /// or [AuthorizationResult.rejected] with the reason if not.
  AuthorizationResult authorize({
    required VoiceRecognitionEvent event,
    required VoiceCommand command,
    required VoiceFeatureContext activeContext,
    required int currentRecognizerSessionId,
    required int currentCommandSessionId,
    required int currentContextGeneration,
  }) {
    // 1. Empty or nonsense
    if (command.intent is UnknownIntent) {
      final text = (command.intent as UnknownIntent).transcript;
      if (text.isEmpty || text == '[unk]' || text == 'unk') {
        return const AuthorizationResult.rejected(
          VoiceRejectionReason.emptyOrNonsense,
        );
      }
      return const AuthorizationResult.rejected(VoiceRejectionReason.lowMatch);
    }

    // 2. Session currency — reject stale recognizer sessions
    if (event.recognizerSessionId < currentRecognizerSessionId) {
      return const AuthorizationResult.rejected(
        VoiceRejectionReason.staleSession,
      );
    }

    // 3. Command session currency
    if (event.commandSessionId < currentCommandSessionId) {
      return const AuthorizationResult.rejected(
        VoiceRejectionReason.staleSession,
      );
    }

    // 4. Context generation check
    if (event.contextGeneration < currentContextGeneration) {
      return const AuthorizationResult.rejected(
        VoiceRejectionReason.staleSession,
      );
    }

    // 5. Expiry check
    if (event.isExpired()) {
      return const AuthorizationResult.rejected(VoiceRejectionReason.expired);
    }

    // 6. Deduplication
    if (!_checkDeduplication(event)) {
      return const AuthorizationResult.rejected(VoiceRejectionReason.duplicate);
    }

    // 7. TTS echo guard
    if (_isSelfEcho(command)) {
      return const AuthorizationResult.rejected(
        VoiceRejectionReason.selfTtsEcho,
      );
    }

    // 8. Emergency commands bypass context, score, and ambiguity checks
    if (VoiceActionRegistry.isEmergency(command.intent)) {
      return const AuthorizationResult.allowed();
    }

    // 9. Context authorization
    final definition = VoiceActionRegistry.getDefinition(command.intent);
    if (definition != null && !definition.isAllowedIn(activeContext)) {
      return const AuthorizationResult.rejected(
        VoiceRejectionReason.wrongContext,
      );
    }

    // 10. Low match score
    if (command.matchScore < 0.4 && command.intent is! UnknownIntent) {
      return const AuthorizationResult.rejected(VoiceRejectionReason.lowMatch);
    }

    // 11. Ambiguity check
    if (command.isAmbiguous) {
      return const AuthorizationResult.rejected(VoiceRejectionReason.ambiguous);
    }

    // 12. Circuit breaker
    final canonicalName =
        definition?.canonicalName ?? command.intent.runtimeType.toString();
    if (!circuitBreaker.recordAndCheck(canonicalName)) {
      return const AuthorizationResult.rejected(
        VoiceRejectionReason.commandLoopSuppressed,
      );
    }

    return const AuthorizationResult.allowed();
  }

  bool _checkDeduplication(VoiceRecognitionEvent event) =>
      deduplicator.consume(event.recognitionId);

  bool _isSelfEcho(VoiceCommand command) {
    if (!ttsEchoGuard.isSpeaking) return false;
    return ttsEchoGuard.isSelfEcho(command.normalizedTranscript);
  }
}
