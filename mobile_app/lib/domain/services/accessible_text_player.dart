import 'dart:async';

import '../../app/voice_kernel/voice_diagnostic_logger.dart';
import '../entities/accessible_document.dart';
import '../enums/reading_profile.dart';
import 'document_text_normalizer.dart';
import 'speech_output_service.dart';
import 'tts_echo_guard.dart';

enum PlaybackStatus { idle, playing, paused, completed, error }

/// Authoritative sentence-by-sentence accessible text player and navigator.
///
/// Provides structured document playback, word-level tracking, generation token
/// protection against race conditions and stale native TTS callbacks, and seamless
/// integration with [TtsEchoGuard] for real-time acoustic self-echo prevention.
class AccessibleTextPlayer {
  AccessibleTextPlayer({
    required this.speechService,
    TtsEchoGuard? echoGuard,
    this.onStateChanged,
  }) : echoGuard = echoGuard ?? TtsEchoGuard();

  final SpeechOutputService speechService;
  final TtsEchoGuard echoGuard;
  final void Function()? onStateChanged;

  AccessibleDocument _document = AccessibleDocument.empty;
  int _currentIndex = 0;
  AccessibleWord? _currentWord;
  int _currentRangeStart = 0;
  int _currentRangeEnd = 0;

  PlaybackStatus _status = PlaybackStatus.idle;
  ReadingProfile _profile = ReadingProfile.normal;
  bool _disposed = false;
  int _playGeneration = 0;
  Completer<void>? _activeSentenceCompleter;

  AccessibleDocument get document => _document;
  List<AccessibleSentence> get sentences => _document.sentences;
  List<String> get sentenceTexts =>
      _document.sentences.map((s) => s.text).toList(growable: false);

  int get currentIndex => _currentIndex;
  int get totalSentences => _document.sentences.length;
  int get totalWords => _document.totalWords;

  PlaybackStatus get status => _status;
  ReadingProfile get profile => _profile;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isPaused => _status == PlaybackStatus.paused;
  int get playbackGeneration => _playGeneration;

  AccessibleSentence? get currentSentence =>
      _document.sentenceAt(_currentIndex);

  AccessibleWord? get currentWord => _currentWord;
  int get currentRangeStart => _currentRangeStart;
  int get currentRangeEnd => _currentRangeEnd;

  /// Compatibility helper for splitting raw text into clean sentences.
  static List<String> splitIntoSentences(String text) {
    final doc = DocumentTextNormalizer.normalize(text);
    return doc.sentences.map((s) => s.text).toList(growable: false);
  }

  /// Loads a structured [AccessibleDocument] directly into the player.
  void loadDocument(AccessibleDocument doc) {
    _playGeneration++;
    VoiceDiagnosticLogger.readerEvent(
      event: 'LOAD_DOCUMENT',
      generation: _playGeneration,
      detail: 'sentences=${doc.sentences.length}',
    );
    _document = doc;
    _currentIndex = 0;
    _currentWord = null;
    _currentRangeStart = 0;
    _currentRangeEnd = 0;
    _status = PlaybackStatus.idle;
    echoGuard.onTtsStop();
    _notifyState();
  }

  /// Normalizes and loads raw OCR text string into the player.
  void loadText(String rawText, {String? documentId}) {
    final doc = DocumentTextNormalizer.normalize(
      rawText,
      documentId: documentId,
    );
    loadDocument(doc);
  }

  /// Alias for [loadText] for backward compatibility.
  void load(String rawText, {String? documentId}) =>
      loadText(rawText, documentId: documentId);

  /// Alias for [jumpToSentence] for backward compatibility.
  Future<void> jumpTo(int index) => jumpToSentence(index);

  /// Begins reading the document from the current sentence index.
  Future<void> play() async {
    if (_disposed || _document.isEmpty) return;
    _playGeneration++;
    final generation = _playGeneration;
    VoiceDiagnosticLogger.readerEvent(
      event: 'PLAY',
      generation: generation,
      sentenceIndex: _currentIndex,
    );
    _status = PlaybackStatus.playing;
    _notifyState();
    await _applyProfileRate();

    while (_currentIndex < _document.sentences.length &&
        _status == PlaybackStatus.playing &&
        _playGeneration == generation &&
        !_disposed) {
      final sent = _document.sentenceAt(_currentIndex);
      if (sent == null) break;
      final utteranceId =
          'scanner:${_document.id}:$generation:sent:$_currentIndex';
      final completer = Completer<void>();
      _activeSentenceCompleter = completer;

      echoGuard.onTtsStart(
        utteranceId: utteranceId,
        sentenceId: sent.id,
        sentenceText: sent.text,
        generation: generation,
      );

      await speechService.speakSentence(
        utteranceId,
        sent.text,
        onStart: () {
          VoiceDiagnosticLogger.readerTtsCallback(
            event: 'onStart',
            generation: generation,
            currentGeneration: _playGeneration,
            sentenceIndex: _currentIndex,
          );
          if (_playGeneration != generation || _disposed) return;
          _notifyState();
        },
        onProgress: (start, end, word) {
          if (_playGeneration != generation || _disposed) return;
          _currentRangeStart = start;
          _currentRangeEnd = end;
          _currentWord = sent.wordAtSentenceOffset(start);
          echoGuard.onTtsRange(
            utteranceId: utteranceId,
            rangeStart: start,
            rangeEnd: end,
            word: word,
            generation: generation,
          );
          _notifyState();
        },
        onDone: () {
          VoiceDiagnosticLogger.readerTtsCallback(
            event: 'onDone',
            generation: generation,
            currentGeneration: _playGeneration,
            sentenceIndex: _currentIndex,
          );
          if (!completer.isCompleted) completer.complete();
        },
        onError: (error) {
          VoiceDiagnosticLogger.readerTtsCallback(
            event: 'onError',
            generation: generation,
            currentGeneration: _playGeneration,
            sentenceIndex: _currentIndex,
          );
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Await sentence completion or early interruption
      await completer.future;
      if (_playGeneration != generation ||
          _status != PlaybackStatus.playing ||
          _disposed) {
        break;
      }

      echoGuard.onTtsDone(utteranceId: utteranceId, generation: generation);

      if (_currentIndex < _document.sentences.length - 1) {
        _currentIndex++;
        _currentWord = null;
        _currentRangeStart = 0;
        _currentRangeEnd = 0;
        _notifyState();

        final pauseDuration = _profile.pauseDuration;
        if (pauseDuration > Duration.zero) {
          await Future.delayed(pauseDuration);
        }
      } else {
        _status = PlaybackStatus.completed;
        _notifyState();
        break;
      }
    }
  }

  /// Pauses playback immediately while preserving current sentence and word position.
  Future<void> pause() async {
    _playGeneration++;
    VoiceDiagnosticLogger.readerEvent(
      event: 'PAUSE',
      generation: _playGeneration,
      sentenceIndex: _currentIndex,
    );
    _status = PlaybackStatus.paused;
    _completeActiveSentence();
    echoGuard.onTtsStop();
    await speechService.stop();
    _notifyState();
  }

  /// Resumes playback from the exact paused sentence position.
  Future<void> resume() async {
    if (_disposed || _document.isEmpty) return;
    if (_status == PlaybackStatus.completed) {
      _currentIndex = 0;
    }
    VoiceDiagnosticLogger.readerEvent(
      event: 'RESUME',
      generation: _playGeneration,
      sentenceIndex: _currentIndex,
    );
    await play();
  }

  /// Repeats the active sentence from the beginning.
  Future<void> repeat() async {
    if (_disposed || _document.isEmpty) return;
    _currentWord = null;
    _currentRangeStart = 0;
    _currentRangeEnd = 0;
    _playGeneration++;
    VoiceDiagnosticLogger.readerEvent(
      event: 'REPEAT',
      generation: _playGeneration,
      sentenceIndex: _currentIndex,
    );
    _completeActiveSentence();
    echoGuard.onTtsStop();
    await speechService.stop();
    await play();
  }

  /// Advances to the next sentence.
  Future<void> next() async {
    if (_disposed || _document.isEmpty) return;
    if (_currentIndex < _document.sentences.length - 1) {
      _currentIndex++;
      _currentWord = null;
      _currentRangeStart = 0;
      _currentRangeEnd = 0;
      _playGeneration++;
      VoiceDiagnosticLogger.readerEvent(
        event: 'NEXT',
        generation: _playGeneration,
        sentenceIndex: _currentIndex,
      );
      _completeActiveSentence();
      echoGuard.onTtsStop();
      await speechService.stop();
      await play();
    } else {
      _status = PlaybackStatus.completed;
      _playGeneration++;
      _completeActiveSentence();
      echoGuard.onTtsStop();
      await speechService.stop();
      _notifyState();
    }
  }

  /// Jumps back to the previous sentence.
  Future<void> previous() async {
    if (_disposed || _document.isEmpty) return;
    final target = _currentIndex > 0 ? _currentIndex - 1 : 0;
    VoiceDiagnosticLogger.readerEvent(
      event: 'PREVIOUS',
      generation: _playGeneration + 1,
      sentenceIndex: target,
    );
    await jumpToSentence(target);
  }

  /// Jumps directly to a specific sentence index.
  Future<void> jumpToSentence(int index) async {
    if (_disposed || _document.isEmpty) return;
    final target = index.clamp(0, _document.sentences.length - 1);
    _currentIndex = target;
    _currentWord = null;
    _currentRangeStart = 0;
    _currentRangeEnd = 0;
    _playGeneration++;
    _completeActiveSentence();
    echoGuard.onTtsStop();
    await speechService.stop();
    await play();
  }

  /// Restarts playback from the very first sentence.
  Future<void> restart() async {
    await jumpToSentence(0);
  }

  /// Starts reading from the final sentence.
  Future<void> readLast() async {
    if (_disposed || _document.isEmpty) return;
    await jumpToSentence(_document.sentences.length - 1);
  }

  /// Starts reading from a one-based line number, clamped to the document.
  Future<void> readLine(int lineNumber) async {
    if (_disposed || _document.isEmpty) return;
    await jumpToSentence(lineNumber - 1);
  }

  /// Stops all audio output and sets status to idle.
  Future<void> stop() async {
    _playGeneration++;
    _status = PlaybackStatus.idle;
    _currentWord = null;
    _currentRangeStart = 0;
    _currentRangeEnd = 0;
    _completeActiveSentence();
    echoGuard.onTtsStop();
    await speechService.stop();
    _notifyState();
  }

  /// Changes the reading speed profile and adjusts TTS rate dynamically.
  Future<void> setProfile(ReadingProfile profile) async {
    _profile = profile;
    await _applyProfileRate();
    _notifyState();
  }

  /// Spells out the complete current reading line letter-by-letter.
  Future<void> spellCurrent() async {
    final sent = currentSentence;
    if (sent == null || _disposed) return;
    _playGeneration++;
    final generation = _playGeneration;
    _status = PlaybackStatus.playing;
    _notifyState();
    await speechService.stop();

    final spelled = sent.text
        .split('')
        .where((c) => RegExp(r'[A-Za-z0-9]').hasMatch(c))
        .map((c) => c.toUpperCase())
        .join(', ');

    final utteranceId =
        'scanner:${_document.id}:$generation:spell:$_currentIndex';
    echoGuard.onTtsStart(
      utteranceId: utteranceId,
      sentenceId: sent.id,
      sentenceText: spelled,
      generation: generation,
    );

    await speechService.speakSentence(
      utteranceId,
      spelled,
      onDone: () {
        if (_playGeneration != generation || _disposed) return;
        _status = PlaybackStatus.paused;
        echoGuard.onTtsDone(utteranceId: utteranceId, generation: generation);
        _notifyState();
      },
    );
  }

  Future<void> _applyProfileRate() async {
    try {
      await speechService.setSpeechRate(_profile.rate);
    } catch (_) {}
  }

  void _notifyState() {
    if (!_disposed) {
      onStateChanged?.call();
    }
  }

  void _completeActiveSentence() {
    final completer = _activeSentenceCompleter;
    _activeSentenceCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _playGeneration++;
    _completeActiveSentence();
    echoGuard.onTtsStop();
    await speechService.stop();
  }
}
