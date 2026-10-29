import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/speech_output_service.dart';

class _SpeechTurn {
  _SpeechTurn(this.text, {this.onStart, this.onProgress});
  final String text;
  final void Function()? onStart;
  final void Function(int, int, String)? onProgress;
  final cancelled = Completer<void>();
  final error = Completer<String>();
}

/// One owner for assistant and reader speech, including interrupted utterances.
class FlutterTtsSpeechOutputService implements SpeechOutputService {
  FlutterTtsSpeechOutputService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  _SpeechTurn? _active;
  int _requestGeneration = 0;

  @override
  bool get isSpeaking => _active != null;

  void _installCallbacks() {
    _tts.setStartHandler(() => _active?.onStart?.call());
    _tts.setProgressHandler((text, start, end, word) {
      final turn = _active;
      if (turn != null && text == turn.text) {
        turn.onProgress?.call(start, end, word);
      }
    });
    // The awaited speak result belongs to its own turn. Global completion and
    // cancel events have no utterance ID and can arrive after a replacement.
    _tts.setCompletionHandler(() {});
    _tts.setCancelHandler(() {});
    _tts.setErrorHandler((message) {
      final turn = _active;
      if (turn != null && !turn.error.isCompleted) {
        turn.error.complete(message.toString());
      }
    });
  }

  Future<void> _speak(
    String text, {
    void Function()? onStart,
    void Function(int, int, String)? onProgress,
    void Function()? onDone,
    void Function(String)? onError,
    required bool sentence,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      onDone?.call();
      return;
    }
    // A replacement never leaves its old awaiting caller or callbacks active.
    final request = ++_requestGeneration;
    if (_active != null) await _stopCurrent();
    if (_requestGeneration != request) return;
    final turn = _SpeechTurn(cleaned, onStart: onStart, onProgress: onProgress);
    _active = turn;
    _installCallbacks();
    try {
      // Mobile feedback shares the engine and may have changed its completion
      // mode/handlers. Reclaim them for every new utterance, not once per app.
      await _tts.awaitSpeakCompletion(true);
      if (!identical(_active, turn)) return;
      final native = _tts.speak(cleaned).then<Object?>((value) => value);
      final timeout = sentence
          ? (cleaned.length * 120).clamp(3000, 30000)
          // Android's selected offline voice and accessibility speech rate can
          // need more than five seconds for the wearable test phrase. A short
          // character budget falsely reported failure after audible speech.
          // Replacement/Stop still cancels immediately; this only bounds a
          // missing native completion, including longer assistant answers.
          : (cleaned.length * 180).clamp(5000, 120000);
      final outcome = await Future.any<Object?>([
        native,
        turn.cancelled.future.then<Object?>((_) => null),
        turn.error.future.then<Object?>((error) => StateError(error)),
      ]).timeout(Duration(milliseconds: timeout));
      if (!identical(_active, turn)) return;
      if (outcome != 1) {
        throw outcome is StateError
            ? outcome
            : StateError('Text-to-speech did not complete the utterance.');
      }
      _active = null;
      onDone?.call();
    } catch (error) {
      if (!identical(_active, turn)) return;
      _active = null;
      // Stop only this failed turn; an expired old future cannot stop new TTS.
      try {
        await _tts.stop();
      } catch (_) {}
      if (onError != null) {
        onError(error.toString());
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> speak(String text) => _speak(text, sentence: false);

  @override
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) => _speak(
    text,
    sentence: true,
    onStart: onStart,
    onProgress: onProgress,
    onDone: onDone,
    onError: onError,
  );

  @override
  Future<void> setSpeechRate(double rate) async {
    final result = await _tts.setSpeechRate(rate.clamp(0.2, 1.0));
    if (result != 1) {
      throw StateError('The speech engine rejected the rate change.');
    }
  }

  @override
  Future<void> stop() async {
    _requestGeneration++;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    final turn = _active;
    _active = null;
    if (turn != null && !turn.cancelled.isCompleted) turn.cancelled.complete();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() => stop();
}
