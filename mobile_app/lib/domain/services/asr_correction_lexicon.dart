/// Evidence-driven ASR correction for known Vosk misrecognitions.
///
/// Starts minimal — only corrections that have been observed on real devices
/// (TECNO BG6, etc.). Grows based on real-world voice diagnostic logs.
///
/// These corrections run early in the intent resolution pipeline, before
/// semantic normalization.
abstract final class AsrCorrectionLexicon {
  /// Map of known ASR misrecognitions → intended phrases.
  ///
  /// Keys are lowercased normalized misrecognitions. Values are the correct
  /// interpretation. Only include entries with high confidence — false
  /// corrections are worse than missed ones.
  static const Map<String, String> corrections = {
    // Vosk commonly splits "AI" or misrecognizes it
    'vision a i': 'vision ai',
    'hey vision a i': 'hey vision ai',
    'hi vision a i': 'hi vision ai',
    'hey visual i': 'hey vision ai',
    'hi visual i': 'hi vision ai',
    'hay vision': 'hey vision',
    'hey vision aye': 'hey vision ai',
    'hey vision eye': 'hey vision ai',

    // Common Vosk misrecognitions for command words
    'sellout': 'spell out',
    'sell out': 'spell out',

    // "scan" sometimes heard as "skin" or "span"
    'skin document': 'scan document',
    'span document': 'scan document',

    // "pause" sometimes heard as "paws" or "poss"
    'paws': 'pause',
    'poss': 'pause',

    // "resume" sometimes heard as "result"
    'result reading': 'resume reading',
  };

  /// Applies known ASR corrections to the transcript.
  ///
  /// Returns the corrected text, or the original if no corrections apply.
  static String correct(String text) {
    if (text.isEmpty) return text;

    // Check for exact full-phrase corrections first.
    final exactMatch = corrections[text];
    if (exactMatch != null) return exactMatch;

    // Apply substring corrections for longer utterances.
    var corrected = text;
    for (final entry in corrections.entries) {
      if (corrected.contains(entry.key)) {
        corrected = corrected.replaceFirst(entry.key, entry.value);
      }
    }
    return corrected;
  }
}
