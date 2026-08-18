/// Speaks assistant responses and document sentences through the platform text-to-speech engine.
///
/// Keeping this contract in the domain layer prevents application controllers
/// from depending directly on a Flutter plugin.
abstract interface class SpeechOutputService {
  bool get isSpeaking;

  /// Speaks short conversational assistant responses.
  Future<void> speak(String text);

  /// Speaks a structured document sentence with authoritative progress callbacks.
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  });

  Future<void> setSpeechRate(double rate);

  Future<void> stop();

  Future<void> dispose();
}
