import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/tts_service.dart';

class FlutterTtsService implements TtsService {
  FlutterTtsService();

  FlutterTts? _tts;
  bool _speaking = false;
  bool _initialized = false;
  String? _engineError;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    _engineError = null;
    _tts = FlutterTts();

    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(0.5);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);
    await _tts!.setQueueMode(0);
    await _tts!.awaitSpeakCompletion(false);

    _tts!.setStartHandler(() {
      _speaking = true;
    });

    _tts!.setCompletionHandler(() {
      _speaking = false;
    });

    _tts!.setCancelHandler(() {
      _speaking = false;
    });

    _tts!.setErrorHandler((msg) {
      _speaking = false;
      _engineError = msg;
    });

    _initialized = true;
  }

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (_tts == null || !_initialized) {
      throw StateError('Text-to-speech is not initialized');
    }
    if (_engineError case final error?) {
      _engineError = null;
      throw StateError('Text-to-speech engine error: $error');
    }

    if (interrupt && _speaking) {
      await _tts!.stop();
    }

    if (_speaking && !interrupt) return;

    await _tts!.speak(text);
  }

  @override
  Future<void> stop() async {
    if (_tts == null) return;
    await _tts!.stop();
    _speaking = false;
  }

  @override
  Future<void> dispose() async {
    await stop();
    _tts = null;
    _initialized = false;
    _engineError = null;
  }
}
