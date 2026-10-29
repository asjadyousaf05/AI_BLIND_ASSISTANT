import '../entities/voice_command.dart';
import '../enums/voice_intent.dart';

/// Only reversible reader controls may interrupt speech before ASR silence.
abstract final class ReaderVoiceCommandPolicy {
  static bool allowsImmediate(VoiceCommand command) {
    if (command.isAmbiguous || command.matchScore < 0.85) return false;
    final words = command.normalizedTranscript.split(' ');
    if (words.length < 2) return false;
    final readerControl = switch (command.intent) {
      Silence() ||
      ReadDocumentAgain() ||
      ReadingPause() ||
      ReadingResume() ||
      ReadingNext() ||
      ReadingPrevious() ||
      ReadingRepeat() ||
      ReadingRestart() ||
      ReadingLast() ||
      ReadingGoToLine() ||
      ReadingSpell() ||
      SetReadingProfile() => true,
      _ => false,
    };
    if (!readerControl) return false;
    return command.matchType == VoiceMatchType.exact ||
        command.matchType == VoiceMatchType.alias ||
        (command.intent is ReadingGoToLine &&
            RegExp(
              r'^(?:go to |read )?(?:the )?(?:line|sentence) [a-z0-9 ]+$',
            ).hasMatch(command.normalizedTranscript));
  }
}
