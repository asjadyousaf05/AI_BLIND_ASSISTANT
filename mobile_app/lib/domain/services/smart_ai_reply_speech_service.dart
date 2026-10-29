/// Local spoken replies with Smart AI-specific language selection.
abstract interface class SmartAiReplySpeechService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}
