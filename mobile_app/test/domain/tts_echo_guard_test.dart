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

    test('permits wake phrases absent from the document speech', () {
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
      expect(guard.isSelfEcho('pause'), isTrue); // Recognition can arrive late.
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

    test(
      'wake echo requires a branded wake phrase, not a generic vision word',
      () {
        guard.onTtsStart(
          utteranceId: 'utt_3',
          sentenceId: 's3',
          sentenceText:
              'Computer vision is a field of artificial intelligence.',
          generation: 3,
        );

        expect(guard.isWakeWordEcho(), isFalse);

        guard.onTtsStart(
          utteranceId: 'utt_4',
          sentenceId: 's4',
          sentenceText: 'This is a normal sentence.',
          generation: 4,
        );

        expect(guard.isWakeWordEcho(), isFalse);
      },
    );

    test('guards phrases anywhere in long speech without progress callbacks', () {
      guard.onTtsStart(
        utteranceId: 'long',
        sentenceId: 's',
        generation: 1,
        sentenceText:
            '${List.filled(20, 'A synthetic example.').join(' ')} Stop reading, and spell out the next line.',
      );
      for (final phrase in ['stop reading', 'spell out', 'next line']) {
        expect(guard.isSelfEcho(phrase), isTrue);
      }
      expect(guard.isSelfEcho('[unk] stop reading [unk]'), isTrue);
      expect(guard.isSelfEcho('read first line'), isFalse);
    });

    test(
      'rejects delayed echo across sentence changes and expires the tail',
      () {
        var now = DateTime.utc(2026, 10, 15);
        guard = TtsEchoGuard(clock: () => now);
        guard.onTtsStart(
          utteranceId: 'one',
          sentenceId: 'one',
          generation: 1,
          sentenceText: 'The manual says pause reading.',
        );
        guard.onTtsDone(utteranceId: 'one', generation: 1);
        guard.onTtsStart(
          utteranceId: 'two',
          sentenceId: 'two',
          generation: 1,
          sentenceText: 'The next sentence is unrelated.',
        );
        now = now.add(const Duration(milliseconds: 1000));
        expect(guard.isSelfEcho('pause reading'), isTrue);
        now = now.add(const Duration(milliseconds: 501));
        expect(guard.isSelfEcho('pause reading'), isFalse);
      },
    );

    test(
      'utterance identity protects against callbacks with the same generation',
      () {
        guard.onTtsStart(
          utteranceId: 'new',
          sentenceId: 's',
          generation: 1,
          sentenceText: 'An unrelated example.',
        );
        guard.onTtsRange(
          utteranceId: 'old',
          generation: 1,
          rangeStart: 0,
          rangeEnd: 4,
          word: 'stop',
        );
        guard.onTtsDone(utteranceId: 'old', generation: 1);
        expect(guard.isSpeaking, isTrue);
        expect(guard.activeWordText, isEmpty);
      },
    );

    test(
      'does not allow document speech to bypass protection with a wake prefix',
      () {
        guard.onTtsStart(
          utteranceId: 'wake',
          sentenceId: 's',
          generation: 1,
          sentenceText: 'An example command is Hey Vision AI stop reading.',
        );
        expect(guard.isSelfEcho('hey vision ai stop reading'), isTrue);
        expect(guard.isWakeWordEcho(), isTrue);
        guard.onTtsStop();
        expect(guard.isWakeWordEcho(), isTrue);
      },
    );

    test('spoken Listen Vision AI guidance cannot wake its own listener', () {
      guard.onTtsStart(
        utteranceId: 'guide',
        sentenceId: 'guide',
        generation: 1,
        sentenceText: 'Say Listen Vision AI to request a command.',
      );
      expect(guard.isWakeWordEcho(), true);
      guard.onTtsStop();
      expect(guard.isWakeWordEcho(), true);
    });

    test('uses whole words and protects spelling output', () {
      guard.onTtsStart(
        utteranceId: 'words',
        sentenceId: 's',
        generation: 1,
        sentenceText: 'A nonstop bus passes.',
      );
      expect(guard.isSelfEcho('stop'), isFalse);
      guard.onTtsStart(
        utteranceId: 'spell',
        sentenceId: 's',
        generation: 2,
        sentenceText: 'S, T, O, P',
      );
      expect(guard.isSelfEcho('stop'), isTrue);
    });
  });
}
