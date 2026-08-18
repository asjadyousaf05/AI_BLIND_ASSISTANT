import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/app/voice_kernel/command_authorizer.dart';
import 'package:ai_blind_assistant/app/voice_kernel/command_circuit_breaker.dart';
import 'package:ai_blind_assistant/app/voice_kernel/command_deduplicator.dart';
import 'package:ai_blind_assistant/domain/entities/voice_command.dart';
import 'package:ai_blind_assistant/domain/entities/voice_recognition_event.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/enums/voice_intent.dart';
import 'package:ai_blind_assistant/domain/enums/voice_rejection_reason.dart';
import 'package:ai_blind_assistant/domain/services/tts_echo_guard.dart';

void main() {
  group('CommandDeduplicator', () {
    test('consumes unique IDs exactly once', () {
      final deduplicator = CommandDeduplicator();

      expect(deduplicator.isDuplicate('rec_1'), isFalse);
      expect(deduplicator.consume('rec_1'), isTrue);
      expect(deduplicator.isDuplicate('rec_1'), isTrue);
      expect(deduplicator.consume('rec_1'), isFalse);
    });

    test('evicts oldest entries when capacity is exceeded', () {
      final deduplicator = CommandDeduplicator(maxEntries: 2);

      deduplicator.consume('rec_1');
      deduplicator.consume('rec_2');
      deduplicator.consume('rec_3');

      expect(deduplicator.length, equals(2));
      expect(deduplicator.isDuplicate('rec_1'), isFalse); // Evicted
      expect(deduplicator.isDuplicate('rec_2'), isTrue);
      expect(deduplicator.isDuplicate('rec_3'), isTrue);
    });
  });

  group('CommandCircuitBreaker', () {
    test('allows up to maxRepeats within window then trips', () {
      final breaker = CommandCircuitBreaker(
        maxRepeats: 3,
        window: const Duration(seconds: 5),
      );

      expect(breaker.recordAndCheck('stop_detection'), isTrue);
      expect(breaker.recordAndCheck('stop_detection'), isTrue);
      expect(breaker.recordAndCheck('stop_detection'), isFalse); // 3rd repeat trips
      expect(breaker.isTripped, isTrue);
    });

    test('reset clears trip state and history', () {
      final breaker = CommandCircuitBreaker(maxRepeats: 2);

      breaker.recordAndCheck('stop_detection');
      breaker.recordAndCheck('stop_detection');
      expect(breaker.isTripped, isTrue);

      breaker.reset();
      expect(breaker.isTripped, isFalse);
      expect(breaker.recordAndCheck('stop_detection'), isTrue);
    });
  });

  group('CommandAuthorizer - Stale Session & Context Protection', () {
    late CommandDeduplicator deduplicator;
    late CommandCircuitBreaker circuitBreaker;
    late TtsEchoGuard ttsEchoGuard;
    late CommandAuthorizer authorizer;

    setUp(() {
      deduplicator = CommandDeduplicator();
      circuitBreaker = CommandCircuitBreaker();
      ttsEchoGuard = TtsEchoGuard();
      authorizer = CommandAuthorizer(
        deduplicator: deduplicator,
        circuitBreaker: circuitBreaker,
        ttsEchoGuard: ttsEchoGuard,
      );
    });

    test('rejects event with stale recognizerSessionId', () {
      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_stale',
        recognizerSessionId: 1,
        commandSessionId: 5,
        contextGeneration: 3,
        transcript: 'stop detection',
        timestamp: DateTime.now(),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: StopMobileDetection(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );

      final result = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.mobileDetection,
        currentRecognizerSessionId: 2, // Newer session!
        currentCommandSessionId: 5,
        currentContextGeneration: 3,
      );

      expect(result.isAllowed, isFalse);
      expect(result.rejection, equals(VoiceRejectionReason.staleSession));
    });

    test('rejects event from previous screen context (stale generation)', () {
      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_prev_screen',
        recognizerSessionId: 2,
        commandSessionId: 5,
        contextGeneration: 1, // Came from generation 1!
        transcript: 'stop detection',
        timestamp: DateTime.now(),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: StopMobileDetection(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );

      final result = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.home,
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 6,
        currentContextGeneration: 2, // We are now on generation 2
      );

      expect(result.isAllowed, isFalse);
      expect(result.rejection, equals(VoiceRejectionReason.staleSession));
    });

    test('rejects expired events older than maxAge', () {
      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_old',
        recognizerSessionId: 2,
        commandSessionId: 5,
        contextGeneration: 2,
        transcript: 'stop detection',
        timestamp: DateTime.now().subtract(const Duration(seconds: 15)),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: StopMobileDetection(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );

      final result = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.mobileDetection,
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 5,
        currentContextGeneration: 2,
      );

      expect(result.isAllowed, isFalse);
      expect(result.rejection, equals(VoiceRejectionReason.expired));
    });

    test('rejects duplicate recognition IDs', () {
      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_dup',
        recognizerSessionId: 2,
        commandSessionId: 5,
        contextGeneration: 2,
        transcript: 'stop detection',
        timestamp: DateTime.now(),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: StopMobileDetection(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );

      // First authorization succeeds
      final first = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.mobileDetection,
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 5,
        currentContextGeneration: 2,
      );
      expect(first.isAllowed, isTrue);

      // Second authorization with same event is rejected as duplicate
      final second = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.mobileDetection,
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 5,
        currentContextGeneration: 2,
      );
      expect(second.isAllowed, isFalse);
      expect(second.rejection, equals(VoiceRejectionReason.duplicate));
    });

    test('rejects commands in forbidden feature contexts', () {
      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_wrong_context',
        recognizerSessionId: 2,
        commandSessionId: 5,
        contextGeneration: 2,
        transcript: 'next sentence',
        timestamp: DateTime.now(),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: ReadingNext(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );

      // Reader commands are only allowed in scannerReading context!
      final result = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.home, // On Home screen!
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 5,
        currentContextGeneration: 2,
      );

      expect(result.isAllowed, isFalse);
      expect(result.rejection, equals(VoiceRejectionReason.wrongContext));
    });

    test('emergency stop bypasses context restrictions', () {
      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_emergency',
        recognizerSessionId: 2,
        commandSessionId: 5,
        contextGeneration: 2,
        transcript: 'emergency stop',
        timestamp: DateTime.now(),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: EmergencyStop(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
      );

      final result = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.unknown,
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 5,
        currentContextGeneration: 2,
      );

      expect(result.isAllowed, isTrue);
    });

    test('rejects self TTS echo when TTS is actively speaking the same word', () {
      ttsEchoGuard.onTtsStart(
        utteranceId: 'utt_1',
        sentenceId: 'sent_1',
        sentenceText: 'Please stop before crossing the street',
        generation: 1,
      );
      ttsEchoGuard.onTtsRange(
        utteranceId: 'utt_1',
        rangeStart: 7,
        rangeEnd: 11,
        word: 'stop',
        generation: 1,
      );

      final event = VoiceRecognitionEvent(
        recognitionId: 'rec_echo',
        recognizerSessionId: 2,
        commandSessionId: 5,
        contextGeneration: 2,
        transcript: 'stop',
        timestamp: DateTime.now(),
        isFinal: true,
      );
      const command = VoiceCommand(
        intent: Silence(),
        matchScore: 1.0,
        matchType: VoiceMatchType.exact,
        normalizedTranscript: 'stop',
      );

      final result = authorizer.authorize(
        event: event,
        command: command,
        activeContext: VoiceFeatureContext.scannerReading,
        currentRecognizerSessionId: 2,
        currentCommandSessionId: 5,
        currentContextGeneration: 2,
      );

      expect(result.isAllowed, isFalse);
      expect(result.rejection, equals(VoiceRejectionReason.selfTtsEcho));
    });
  });
}
