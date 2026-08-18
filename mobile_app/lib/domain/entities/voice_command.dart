import '../enums/voice_intent.dart';

/// The type of phrase match that produced the intent.
enum VoiceMatchType {
  /// Exact canonical phrase matched.
  exact,

  /// A registered alias matched.
  alias,

  /// Semantic verb+entity composition matched.
  semantic,

  /// Token similarity / fuzzy matching.
  fuzzy,

  /// Conversation pattern matched.
  conversation,
}

/// A resolved voice command produced by the intent resolver.
///
/// Contains the matched intent, extracted slots, match quality metadata,
/// and any alternative interpretations for ambiguity detection.
class VoiceCommand {
  const VoiceCommand({
    required this.intent,
    required this.matchScore,
    required this.matchType,
    this.slots = const {},
    this.alternatives = const [],
    this.originalTranscript = '',
    this.normalizedTranscript = '',
  });

  /// The primary matched intent.
  final VoiceIntent intent;

  /// Confidence score for this match (0.0–1.0).
  final double matchScore;

  /// How the match was produced.
  final VoiceMatchType matchType;

  /// Extracted parameter slots (e.g., {'level': 'high'}).
  final Map<String, dynamic> slots;

  /// Alternative intent interpretations ranked by score.
  final List<VoiceCommand> alternatives;

  /// The raw transcript before normalization.
  final String originalTranscript;

  /// The transcript after normalization, correction, and cleanup.
  final String normalizedTranscript;

  /// Whether this command has competing alternatives above the ambiguity
  /// threshold.
  bool get isAmbiguous =>
      intent is AmbiguousIntent ||
      (alternatives.isNotEmpty &&
          alternatives.first.matchScore >= matchScore * 0.85);

  /// Whether this command was unrecognized.
  bool get isUnrecognized => intent is UnknownIntent;

  @override
  String toString() =>
      'VoiceCommand('
      'intent=${intent.runtimeType}, '
      'score=$matchScore, '
      'type=$matchType'
      ')';
}
