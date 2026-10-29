/// Existing local microphone/speech ownership, injected into Smart AI only.
abstract interface class SmartAiAudioCoordinator {
  Stream<void> get goodbyeRequests;
  Future<void> acquire();
  Future<void> prepareRecording();
  Future<void> recordingFinished();
  Future<void> release();
  Future<String?> routeLocalControl(String transcript);
  Future<void> speak(String text);
  Future<void> stopSpeech();
  Future<void> pauseSpeech();
  Future<void> resumeSpeech();
  Future<void> recordingStartedCue();
  Future<void> stopRecordingCue();
}
