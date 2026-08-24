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

    test('pauses and resumes reading', () async {
      player.load('First line. Second line. Third line.');
      await player.pause();
      expect(player.status, PlaybackStatus.paused);
      expect(speech.stopCalls, 1);

      await player.resume();
      expect(speech.spokenTexts, [
        'First line.',
        'Second line.',
        'Third line.',
      ]);
      expect(player.status, PlaybackStatus.completed);
    });

    test('direct line navigation reads from the requested line', () async {
      player.load('Line one. Line two. Line three.');
      await player.readLine(2);
      expect(speech.spokenTexts, ['Line two.', 'Line three.']);

      speech.spokenTexts.clear();
      player.load('Line one. Line two. Line three.');
      await player.readLast();
      expect(speech.spokenTexts, ['Line three.']);
    });

    test('spellCurrent spells the complete current reading line', () async {
      player.load('Read this whole line. Another line.');

      await player.spellCurrent();

      expect(
        speech.spokenTexts.single,
        'R, E, A, D, T, H, I, S, W, H, O, L, E, L, I, N, E',
      );
      expect(player.status, PlaybackStatus.paused);
    });

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
