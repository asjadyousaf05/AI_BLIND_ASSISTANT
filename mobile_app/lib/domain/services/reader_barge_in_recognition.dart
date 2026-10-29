/// Optional phone-local capability for interrupting document speech.
/// Candidates do not execute until the application checks context and echo.
abstract interface class ReaderBargeInRecognition {
  Future<void> setReaderPlaybackActive(bool active);

  /// Atomically claims a still-current candidate and pauses its decoder.
  Future<bool> acceptReaderCommandCandidate(String candidateId);
}
