import 'dart:math' as math;

/// Component that tracks live TTS speech output to guard against self-echo ASR triggers.
class TtsEchoGuard {
  TtsEchoGuard();

  String? _activeUtteranceId;
  String? _activeSentenceId;
  String _activeSentenceText = '';
  String _activeWordText = '';
  int _activeRangeStart = 0;
  int _activeRangeEnd = 0;
  int _playbackGeneration = 0;
  DateTime? _lastRangeTimestamp;
  bool _isSpeaking = false;

  String? get activeUtteranceId => _activeUtteranceId;
  String? get activeSentenceId => _activeSentenceId;
  String get activeSentenceText => _activeSentenceText;
  String get activeWordText => _activeWordText;
  int get activeRangeStart => _activeRangeStart;
  int get activeRangeEnd => _activeRangeEnd;
  int get playbackGeneration => _playbackGeneration;
  bool get isSpeaking => _isSpeaking;

  /// Notifies the guard that a new sentence utterance has started speaking.
  void onTtsStart({
    required String utteranceId,
    required String sentenceId,
    required String sentenceText,
    required int generation,
  }) {
    _activeUtteranceId = utteranceId;
    _activeSentenceId = sentenceId;
    _activeSentenceText = sentenceText;
    _activeWordText = '';
    _activeRangeStart = 0;
    _activeRangeEnd = 0;
    _playbackGeneration = generation;
    _lastRangeTimestamp = DateTime.now();
    _isSpeaking = true;
  }

  /// Updates the currently spoken character range and word token within the active sentence.
  void onTtsRange({
    required String utteranceId,
    required int rangeStart,
    required int rangeEnd,
    required String word,
    required int generation,
  }) {
    if (generation != _playbackGeneration) return;
    _activeUtteranceId = utteranceId;
    _activeRangeStart = rangeStart;
    _activeRangeEnd = rangeEnd;
    _activeWordText = word;
    _lastRangeTimestamp = DateTime.now();
  }

  /// Notifies the guard that the current sentence utterance has finished speaking.
  void onTtsDone({required String utteranceId, required int generation}) {
    if (generation != _playbackGeneration) return;
    _isSpeaking = false;
    _activeWordText = '';
  }

  /// Notifies the guard that TTS was stopped or interrupted.
  void onTtsStop() {
    _isSpeaking = false;
    _activeWordText = '';
  }

  /// Determines whether a recognized bare command is likely acoustic self-echo from the phone's speaker.
  ///
  /// Commands delivered with an intentional wake phrase (e.g. "Vision stop", "Hey Vision")
  /// are intentional human invocations and are never flagged as self-echo.
  bool isSelfEcho(
    String command, {
    Duration echoWindow = const Duration(milliseconds: 750),
  }) {
    if (!_isSpeaking) return false;

    final norm = command.trim().toLowerCase();
    if (norm.isEmpty) return false;

    // Wake words ("vision", "hey vision") are intentional user invocations
    if (norm == 'vision' ||
        norm == 'hey vision' ||
        norm.startsWith('vision ') ||
        norm.startsWith('hey vision ')) {
      return false;
    }

    // 1. Check if the active word being pronounced matches the command
    final activeWordNorm = _activeWordText.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final cmdNorm = norm.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (activeWordNorm.isNotEmpty && activeWordNorm == cmdNorm) {
      return true;
    }

    // 2. Check localized neighborhood in the active sentence around the current TTS playback head
    if (_activeSentenceText.isNotEmpty) {
      final sentLower = _activeSentenceText.toLowerCase();
      final windowStart = math.max(0, _activeRangeStart - 20);
      final windowEnd = math.min(sentLower.length, _activeRangeEnd + 25);
      final neighborhood = sentLower.substring(windowStart, windowEnd);

      if (neighborhood.contains(norm)) {
        return true;
      }
    }

    // 3. Check if the entire active sentence contains the command word while TTS is actively emitting sound
    final wordsInSentence = _activeSentenceText
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty);
    if (wordsInSentence.contains(cmdNorm)) {
      final elapsed = DateTime.now().difference(
        _lastRangeTimestamp ?? DateTime.now(),
      );
      if (elapsed <= echoWindow) {
        return true;
      }
    }

    return false;
  }

  /// Determines whether an active TTS sentence is likely to trigger a false wake event.
  /// 
  /// Checks if the TTS is currently speaking and if the active sentence contains
  /// the word "vision".
  bool isWakeWordEcho({
    Duration echoWindow = const Duration(milliseconds: 750),
  }) {
    if (!_isSpeaking) return false;

    // Check localized neighborhood around the playback head
    if (_activeSentenceText.isNotEmpty) {
      final sentLower = _activeSentenceText.toLowerCase();
      final windowStart = math.max(0, _activeRangeStart - 20);
      final windowEnd = math.min(sentLower.length, _activeRangeEnd + 25);
      final neighborhood = sentLower.substring(windowStart, windowEnd);

      if (neighborhood.contains('vision')) {
        return true;
      }
    }

    // Check entire sentence if recently updated
    final wordsInSentence = _activeSentenceText
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty);
    if (wordsInSentence.contains('vision')) {
      final elapsed = DateTime.now().difference(
        _lastRangeTimestamp ?? DateTime.now(),
      );
      if (elapsed <= echoWindow) {
        return true;
      }
    }

    return false;
  }
}
