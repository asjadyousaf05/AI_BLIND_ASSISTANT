/// A typed speech recognition event carrying session and generation metadata.
///
/// Every event produced by the native recognizer is wrapped in this type.
/// The kernel uses [recognizerSessionId] and [commandSessionId] to reject
/// stale callbacks from previous screens or sessions.
class VoiceRecognitionEvent {
  const VoiceRecognitionEvent({
    required this.recognitionId,
    required this.recognizerSessionId,
    required this.commandSessionId,
    required this.contextGeneration,
    required this.transcript,
    required this.timestamp,
    required this.isFinal,
    this.isPartial = false,
    this.confidence,
    this.provider,
  });

  /// Unique identifier for this specific recognition result.
  final String recognitionId;

  /// Monotonically increasing ID of the recognizer session that produced this.
  final int recognizerSessionId;

  /// The command session this event belongs to (incremented on context change).
  final int commandSessionId;

  /// Generation counter — incremented when feature context changes.
  final int contextGeneration;

  /// The recognized transcript text.
  final String transcript;

  /// When this recognition was produced.
  final DateTime timestamp;

  /// Whether this is a final (committed) recognition result.
  final bool isFinal;

  /// Whether this is a partial (in-progress) recognition result.
  final bool isPartial;

  /// Optional confidence score from the recognizer (0.0–1.0).
  final double? confidence;

  /// The recognition provider that produced this event.
  final String? provider;

  /// Whether this event is too old to be executed.
  bool isExpired({Duration maxAge = const Duration(seconds: 8)}) =>
      DateTime.now().difference(timestamp) > maxAge;

  @override
  String toString() {
    final wordCount = transcript
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return 'VoiceRecognitionEvent('
        'id=$recognitionId, '
        'recognizerSession=$recognizerSessionId, '
        'commandSession=$commandSessionId, '
        'gen=$contextGeneration, '
        'final=$isFinal, '
        'words=$wordCount'
        ')';
  }
}
