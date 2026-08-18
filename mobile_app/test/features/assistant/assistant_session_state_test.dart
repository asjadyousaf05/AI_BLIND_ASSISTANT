import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_session_state.dart';
import 'package:ai_blind_assistant/domain/enums/assistant_failure_kind.dart';

void main() {
  group('AssistantSessionState', () {
    test('all states have non-empty user-facing labels', () {
      for (final state in AssistantSessionState.values) {
        expect(state.label, isNotEmpty);
      }
    });

    test('terminal states identify correctly', () {
      expect(AssistantSessionState.idle.isTerminal, isTrue);
      expect(AssistantSessionState.completed.isTerminal, isTrue);
      expect(AssistantSessionState.cancelled.isTerminal, isTrue);
      expect(AssistantSessionState.laptopUnavailable.isTerminal, isTrue);
      expect(AssistantSessionState.error.isTerminal, isTrue);

      expect(AssistantSessionState.listening.isTerminal, isFalse);
      expect(AssistantSessionState.processingAudio.isTerminal, isFalse);
      expect(AssistantSessionState.thinking.isTerminal, isFalse);
    });

    test('active states identify correctly', () {
      expect(AssistantSessionState.listening.isActive, isTrue);
      expect(AssistantSessionState.processingAudio.isActive, isTrue);
      expect(AssistantSessionState.thinking.isActive, isTrue);
      expect(AssistantSessionState.executingAction.isActive, isTrue);
      expect(AssistantSessionState.checkingVoiceAvailability.isActive, isTrue);

      expect(AssistantSessionState.idle.isActive, isFalse);
      expect(AssistantSessionState.completed.isActive, isFalse);
    });

    test('canStartNewSession gate logic', () {
      expect(AssistantSessionState.idle.canStartNewSession, isTrue);
      expect(AssistantSessionState.completed.canStartNewSession, isTrue);
      expect(AssistantSessionState.cancelled.canStartNewSession, isTrue);
      expect(
        AssistantSessionState.laptopUnavailable.canStartNewSession,
        isTrue,
      );

      expect(AssistantSessionState.listening.canStartNewSession, isFalse);
      expect(AssistantSessionState.thinking.canStartNewSession, isFalse);
    });
  });

  group('AssistantFailureKind', () {
    test('all failure kinds have accessible recovery hints', () {
      for (final kind in AssistantFailureKind.values) {
        expect(kind.recoveryHint, isNotEmpty);
      }
    });

    test('microphone permission hints contain clear guidance', () {
      expect(
        AssistantFailureKind.microphonePermissionDenied.recoveryHint,
        contains('Microphone permission'),
      );
      expect(
        AssistantFailureKind.microphonePermissionPermanentlyDenied.recoveryHint,
        contains('settings'),
      );
    });
  });
}
