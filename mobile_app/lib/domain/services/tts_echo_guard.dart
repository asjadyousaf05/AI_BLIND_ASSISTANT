/// In-memory textual protection alongside Android's acoustic echo canceler.
/// Speaker recognition may arrive after a TTS sentence has already finished.
class TtsEchoGuard {
  TtsEchoGuard({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<({String text, DateTime ended})> _recent = [];
  String? _activeUtteranceId;
  String? _activeSentenceId;
  String _activeSentenceText = '';
  String _activeWordText = '';
  int _activeRangeStart = 0;
  int _activeRangeEnd = 0;
  int _playbackGeneration = 0;
  bool _isSpeaking = false;

  String? get activeUtteranceId => _activeUtteranceId;
  String? get activeSentenceId => _activeSentenceId;
  String get activeSentenceText => _activeSentenceText;
  String get activeWordText => _activeWordText;
  int get activeRangeStart => _activeRangeStart;
  int get activeRangeEnd => _activeRangeEnd;
  int get playbackGeneration => _playbackGeneration;
  bool get isSpeaking => _isSpeaking;

  void onTtsStart({
    required String utteranceId,
    required String sentenceId,
    required String sentenceText,
    required int generation,
  }) {
    if (_isSpeaking) _rememberActive();
    _activeUtteranceId = utteranceId;
    _activeSentenceId = sentenceId;
    _activeSentenceText = sentenceText;
    _activeWordText = '';
    _activeRangeStart = 0;
    _activeRangeEnd = 0;
    _playbackGeneration = generation;
    _isSpeaking = true;
  }

  void onTtsRange({
    required String utteranceId,
    required int rangeStart,
    required int rangeEnd,
    required String word,
    required int generation,
  }) {
    if (!_owns(utteranceId, generation) || !_isSpeaking) return;
    _activeRangeStart = rangeStart;
    _activeRangeEnd = rangeEnd;
    _activeWordText = word;
  }

  void onTtsDone({required String utteranceId, required int generation}) {
    if (!_owns(utteranceId, generation)) return;
    onTtsStop();
  }

  void onTtsStop() {
    if (_isSpeaking) _rememberActive();
    _isSpeaking = false;
    _activeWordText = '';
  }

  bool _owns(String utteranceId, int generation) =>
      generation == _playbackGeneration && utteranceId == _activeUtteranceId;

  void _rememberActive() {
    if (_activeSentenceText.isEmpty) return;
    _recent.add((text: _activeSentenceText, ended: _clock()));
    if (_recent.length > 4) _recent.removeAt(0);
  }

  static List<String> _tokens(String text) => RegExp(r'[a-z0-9]+')
      .allMatches(text.toLowerCase())
      .map((match) => match[0]!)
      .toList(growable: false);

  Iterable<String> _outputs(Duration window) sync* {
    if (_isSpeaking) yield _activeSentenceText;
    final now = _clock();
    _recent.removeWhere((item) => now.difference(item.ended) > window);
    for (final item in _recent) {
      yield item.text;
    }
  }

  bool isSelfEcho(
    String command, {
    Duration echoWindow = const Duration(milliseconds: 1500),
  }) {
    final wanted = _tokens(
      command.replaceAll(RegExp(r'\[unk\]', caseSensitive: false), ' '),
    );
    if (wanted.isEmpty) return false;
    for (final output in _outputs(echoWindow)) {
      final words = _tokens(output);
      // A focused decoder can omit intervening words from ordinary narration.
      // Match whole tokens in order, including punctuation and sentence tails.
      var index = 0;
      for (final word in words) {
        if (word == wanted[index] && ++index == wanted.length) return true;
      }
      // Spelling output may be transcribed as a joined word by the decoder.
      if (words.isNotEmpty &&
          words.every((word) => word.length == 1) &&
          words.join().contains(wanted.join())) {
        return true;
      }
    }
    return false;
  }

  bool isWakeWordEcho({
    Duration echoWindow = const Duration(milliseconds: 1500),
  }) => _outputs(echoWindow).any(
    (output) => RegExp(
      r'\b(?:hey|hi|hello|hay|listen) (?:vision|version|visual) (?:ai|a i|i|eye|aye)\b',
    ).hasMatch(_tokens(output).join(' ')),
  );
}
