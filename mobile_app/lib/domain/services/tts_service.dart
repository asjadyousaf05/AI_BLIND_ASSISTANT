abstract interface class TtsService {
  Future<void> initialize();
  Future<void> speak(String text, {bool interrupt, double pan});
  Future<void> setSpeechRate(double rate);
  Future<void> stop();
  Future<void> dispose();
  bool get isSpeaking;
}
