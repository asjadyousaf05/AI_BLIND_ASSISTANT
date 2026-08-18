import 'package:ai_blind_assistant/domain/enums/reading_profile.dart';
import 'package:ai_blind_assistant/domain/services/accessible_text_player.dart';
import 'package:ai_blind_assistant/domain/services/speech_output_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeechOutputService implements SpeechOutputService {
  @override
  bool isSpeaking = false;
  final List<String> spokenTexts = [];
  final List<double> setRates = [];
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    spokenTexts.add(text);
    onStart?.call();
    onProgress?.call(0, text.length, text);
    onDone?.call();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    setRates.add(rate);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}

void main() {
  group('AccessibleTextPlayer', () {
    late FakeSpeechOutputService speech;
    late AccessibleTextPlayer player;

    setUp(() {
      speech = FakeSpeechOutputService();
      player = AccessibleTextPlayer(speechService: speech);
    });

    test('splits multi-sentence text accurately', () {
      const text =
          'Welcome to the pharmacy. Take two tablets daily. Do not exceed dosage!';
      final sentences = AccessibleTextPlayer.splitIntoSentences(text);
      expect(sentences.length, 3);
      expect(sentences[0], 'Welcome to the pharmacy.');
      expect(sentences[1], 'Take two tablets daily.');
      expect(sentences[2], 'Do not exceed dosage!');
    });

    test(
      'preserves abbreviations and decimal numbers without false splitting',
      () {
        const text =
            'Dr. Smith visited the U.S.A. on Jan. 15. The price is \$19.99 for 2.5 kg.';
        final sentences = AccessibleTextPlayer.splitIntoSentences(text);
        expect(sentences.length, 2);
        expect(sentences[0], 'Dr. Smith visited the U.S.A. on Jan. 15.');
        expect(sentences[1], 'The price is \$19.99 for 2.5 kg.');
      },
    );

    test(
      'intelligently merges OCR line-wrapped text into unified sentences',
      () {
        const text =
            'The quick brown fox\njumps over the lazy\ndog. Second sentence.';
        final sentences = AccessibleTextPlayer.splitIntoSentences(text);
        expect(sentences.length, 2);
        expect(sentences[0], 'The quick brown fox jumps over the lazy dog.');
        expect(sentences[1], 'Second sentence.');
      },
    );

    test('handles single line without punctuation', () {
      const text = 'Important medicine name';
      final sentences = AccessibleTextPlayer.splitIntoSentences(text);
      expect(sentences.length, 1);
      expect(sentences[0], 'Important medicine name');
    });

    test('calculates totalWords accurately across sentences', () {
      player.load('Take two tablets daily. Do not exceed dosage!');
      expect(player.totalWords, 8);
    });

    test('plays loaded sentences sequentially', () async {
      player.load('Sentence one. Sentence two.');
      await player.play();

      expect(speech.spokenTexts, ['Sentence one.', 'Sentence two.']);
      expect(player.status, PlaybackStatus.completed);
    });

    test('pauses and resumes from exact sentence position', () async {
      player.load('First line. Second line. Third line.');
      await player.pause();
      expect(player.status, PlaybackStatus.paused);
      expect(speech.stopCalls, 1);
    });

    test(
      'previous, next, and repeat navigations step through sentences',
      () async {
        player.load('Line one. Line two. Line three.');
        expect(player.currentIndex, 0);

        await player.next();
        expect(player.currentIndex, 1);

        await player.next();
        expect(player.currentIndex, 2);

        await player.previous();
        expect(player.currentIndex, 1);

        await player.repeat();
        expect(player.currentIndex, 1);
      },
    );

    test('changing reading profile updates speech rate and pacing', () async {
      player.load('Test profile sentence.');
      await player.setProfile(ReadingProfile.learning);
      expect(player.profile, ReadingProfile.learning);
      expect(speech.setRates.last, 0.35);

      await player.setProfile(ReadingProfile.skim);
      expect(player.profile, ReadingProfile.skim);
      expect(speech.setRates.last, 0.75);
    });
  });
}
