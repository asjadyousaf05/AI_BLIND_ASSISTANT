import 'package:ai_blind_assistant/domain/services/tts_echo_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsEchoGuard', () {
    late TtsEchoGuard guard;

    setUp(() {
      guard = TtsEchoGuard();
    });

    test('returns false when TTS is not speaking', () {
      expect(guard.isSelfEcho('stop'), isFalse);
      expect(guard.isSelfEcho('pause'), isFalse);
    });

    test('always permits intentional wake phrases', () {
      guard.onTtsStart(
        utteranceId: 'utt_1',
        sentenceId: 's1',
        sentenceText: 'Do not stop taking this medicine.',
        generation: 1,
      );

      expect(guard.isSelfEcho('vision'), isFalse);
      expect(guard.isSelfEcho('hey vision'), isFalse);
      expect(guard.isSelfEcho('vision stop'), isFalse);
    });

    test('detects self-echo when spoken word matches command in sentence', () {
      guard.onTtsStart(
        utteranceId: 'utt_1',
        sentenceId: 's1',
        sentenceText: 'Do not stop taking this medicine.',
        generation: 1,
      );

      // Active range is on word "stop" (indices 7 to 11)
      guard.onTtsRange(
        utteranceId: 'utt_1',
        rangeStart: 7,
        rangeEnd: 11,
        word: 'stop',
        generation: 1,
      );

      expect(guard.isSelfEcho('stop'), isTrue);
      expect(guard.isSelfEcho('flashlight'), isFalse);
    });

    test('resets speaking state on onTtsDone and onTtsStop', () {
      guard.onTtsStart(
        utteranceId: 'utt_1',
        sentenceId: 's1',
        sentenceText: 'Please pause here.',
        generation: 1,
      );
      expect(guard.isSpeaking, isTrue);

      guard.onTtsDone(utteranceId: 'utt_1', generation: 1);
      expect(guard.isSpeaking, isFalse);
      expect(guard.isSelfEcho('pause'), isFalse);
    });

    test('ignores updates from older generation tokens', () {
      guard.onTtsStart(
        utteranceId: 'utt_2',
        sentenceId: 's2',
        sentenceText: 'Next line.',
        generation: 2,
      );

      // Stale callback from generation 1
      guard.onTtsRange(
        utteranceId: 'utt_1',
        rangeStart: 0,
        rangeEnd: 4,
        word: 'stop',
        generation: 1,
      );

      expect(guard.activeWordText, isEmpty);
    });

    test('isWakeWordEcho detects the word vision in the active sentence', () {
      guard.onTtsStart(
        utteranceId: 'utt_3',
        sentenceId: 's3',
        sentenceText: 'Computer vision is a field of artificial intelligence.',
        generation: 3,
      );

      // It should be detected even before specific words are highlighted
      // because the sentence contains "vision".
      expect(guard.isWakeWordEcho(), isTrue);

      guard.onTtsStart(
        utteranceId: 'utt_4',
        sentenceId: 's4',
        sentenceText: 'This is a normal sentence.',
        generation: 4,
      );

      expect(guard.isWakeWordEcho(), isFalse);
    });
  });
}
