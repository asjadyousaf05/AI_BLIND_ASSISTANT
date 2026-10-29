/// Optional local feedback after the foreground command microphone is ready.
/// Feedback failure must not disable recognition or start another capture.
abstract interface class VoiceListeningFeedback {
  Future<void> playListeningReadyCue();
}
