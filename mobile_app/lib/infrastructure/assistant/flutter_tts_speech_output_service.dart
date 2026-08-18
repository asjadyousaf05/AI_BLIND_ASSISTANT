import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/speech_output_service.dart';

/// Android TTS implementation for assistant responses and structured document sentence reading.
class FlutterTtsSpeechOutputService implements SpeechOutputService {
  FlutterTtsSpeechOutputService({FlutterTts? tts})
    : _tts = tts ?? FlutterTts() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
      _activeStartCallback?.call();
    });

    _tts.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      _activeProgressCallback?.call(startOffset, endOffset, word);
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      final callback = _activeDoneCallback;
      _clearSentenceCallbacks();
      callback?.call();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _clearSentenceCallbacks();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      final callback = _activeErrorCallback;
      _clearSentenceCallbacks();
      callback?.call(msg.toString());
    });
  }

  final FlutterTts _tts;
  bool _configured = false;
  bool _isSpeaking = false;

  void Function()? _activeStartCallback;
  void Function(int start, int end, String word)? _activeProgressCallback;
  void Function()? _activeDoneCallback;
  void Function(String error)? _activeErrorCallback;

  void _clearSentenceCallbacks() {
    _activeStartCallback = null;
    _activeProgressCallback = null;
    _activeDoneCallback = null;
    _activeErrorCallback = null;
  }

  @override
  bool get isSpeaking => _isSpeaking;

  Future<void> _configure() async {
    if (_configured) return;
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    _clearSentenceCallbacks();
    _isSpeaking = true;
    try {
      await _configure();
      final timeoutMs = (cleaned.length * 80).clamp(1500, 15000);
      await _tts
          .speak(cleaned)
          .timeout(Duration(milliseconds: timeoutMs), onTimeout: () => 0);
    } catch (_) {
      // TalkBack live-region announcements and visible text remain available.
    } finally {
      _isSpeaking = false;
    }
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
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      onDone?.call();
      return;
    }

    _activeStartCallback = onStart;
    _activeProgressCallback = onProgress;
    _activeDoneCallback = onDone;
    _activeErrorCallback = onError;
    _isSpeaking = true;

    try {
      await _configure();
      final timeoutMs = (cleaned.length * 120).clamp(3000, 30000);
      await _tts
          .speak(cleaned)
          .timeout(
            Duration(milliseconds: timeoutMs),
            onTimeout: () {
              final callback = _activeDoneCallback;
              _clearSentenceCallbacks();
              callback?.call();
              return 0;
            },
          );
    } catch (e) {
      final callback = _activeErrorCallback;
      _clearSentenceCallbacks();
      callback?.call(e.toString());
    } finally {
      _isSpeaking = false;
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    try {
      await _configure();
      await _tts.setSpeechRate(rate.clamp(0.2, 1.0));
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    _clearSentenceCallbacks();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() => stop();
}
