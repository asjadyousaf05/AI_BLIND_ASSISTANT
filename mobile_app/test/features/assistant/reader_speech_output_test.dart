import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/flutter_tts_speech_output_service.dart';

class _Tts extends FlutterTts {
  final pending = <Completer<dynamic>>[];
  final texts = <String>[];
  final completionModes = <bool>[];
  VoidCallback? started;
  VoidCallback? completed;
  VoidCallback? cancelled;
  ProgressHandler? progressed;
  ErrorHandler? failed;
  Completer<void>? stopGate;
  Completer<void>? configGate;
  @override
  void setStartHandler(VoidCallback callback) {
    started = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    completed = callback;
  }

  @override
  void setCancelHandler(VoidCallback callback) {
    cancelled = callback;
  }

  @override
  void setProgressHandler(ProgressHandler callback) {
    progressed = callback;
  }

  @override
  void setErrorHandler(ErrorHandler callback) {
    failed = callback;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool enabled) async {
    completionModes.add(enabled);
    await configGate?.future;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    texts.add(text);
    final gate = Completer<dynamic>();
    pending.add(gate);
    return gate.future;
  }

  @override
  Future<dynamic> stop() async {
    await stopGate?.future;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late cancel/completion and old progress cannot finish replacement speech',
    () async {
      final tts = _Tts();
      final service = FlutterTtsSpeechOutputService(tts: tts);
      var firstDone = 0;
      var nextDone = 0;
      var nextProgress = 0;
      final first = service.speakSentence(
        'old',
        'Old synthetic sentence.',
        onDone: () => firstDone++,
      );
      await _tick();
      await service.stop();
      await first;
      final next = service.speakSentence(
        'new',
        'New synthetic sentence.',
        onDone: () => nextDone++,
        onProgress: (_, _, _) => nextProgress++,
      );
      await _tick();
      tts.cancelled?.call();
      tts.completed?.call();
      tts.progressed?.call('Old synthetic sentence.', 0, 3, 'Old');
      tts.pending.first.complete(1);
      await _tick();
      expect(firstDone, 0);
      expect(nextDone, 0);
      expect(nextProgress, 0);
      expect(service.isSpeaking, isTrue);
      tts.progressed?.call('New synthetic sentence.', 0, 3, 'New');
      expect(nextProgress, 1);
      tts.pending.last.complete(1);
      await next;
      expect(nextDone, 1);
      expect(service.isSpeaking, isFalse);
    },
  );
  test(
    'reclaims completion and progress ownership for each utterance',
    () async {
      final tts = _Tts();
      final service = FlutterTtsSpeechOutputService(tts: tts);
      var progressed = false;
      var first = service.speakSentence('first', 'First.');
      await _tick();
      tts.pending.last.complete(1);
      await first;
      tts.setProgressHandler(
        (_, _, _, _) => fail('Other owner still installed'),
      );
      var next = service.speakSentence(
        'next',
        'Next.',
        onProgress: (_, _, _) => progressed = true,
      );
      await _tick();
      tts.progressed?.call('Next.', 0, 4, 'Next');
      tts.pending.last.complete(1);
      await next;
      expect(progressed, isTrue);
      expect(tts.completionModes, [true, true]);
    },
  );
  test(
    'stopping during TTS configuration cannot start delayed audio',
    () async {
      final tts = _Tts()..configGate = Completer<void>();
      final service = FlutterTtsSpeechOutputService(tts: tts);
      final speaking = service.speak('Delayed speech.');
      await _tick();
      await service.stop();
      tts.configGate!.complete();
      await speaking;
      expect(tts.texts, isEmpty);
    },
  );
  test('the most recent replacement wins a pending stop race', () async {
    final tts = _Tts();
    final service = FlutterTtsSpeechOutputService(tts: tts);
    final initial = service.speak('First.');
    await _tick();
    tts.stopGate = Completer<void>();
    final superseded = service.speak('Superseded.');
    await _tick();
    final last = service.speak('Last.');
    await _tick();
    tts.stopGate!.complete();
    await superseded;
    await initial;
    expect(tts.texts, ['First.', 'Last.']);
    tts.pending.last.complete(1);
    await last;
  });
  test('native speech failure reports reader error once', () async {
    final tts = _Tts();
    final service = FlutterTtsSpeechOutputService(tts: tts);
    final errors = <String>[];
    final speaking = service.speakSentence(
      'one',
      'A synthetic line.',
      onError: errors.add,
    );
    await _tick();
    tts.failed?.call('Synthetic engine failure');
    await speaking;
    expect(errors, hasLength(1));
    expect(service.isSpeaking, isFalse);
    tts.pending.last.complete(0);
  });
}
