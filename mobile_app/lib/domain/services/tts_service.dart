abstract interface class TtsService {
  Future<void> initialize();
  Future<void> speak(String text, {bool interrupt});
  Future<void> stop();
  Future<void> dispose();
  bool get isSpeaking;
}
