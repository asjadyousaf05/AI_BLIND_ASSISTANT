/// Abstracts push-to-talk audio recording.
///
/// Contract:
/// - Never activate without a user gesture.
/// - Cap recording at [maxDurationSeconds].
/// - Cap payload at [maxFileSizeBytes].
/// - Write audio to a temporary file (WAV or m4a).
/// - Delete the temporary file immediately after the caller processes it.
/// - Never continuously record in the background.
/// - Never record without RECORD_AUDIO permission.
/// - Coordinate with TTS to prevent recording the assistant's own speech.
abstract interface class AudioRecorderService {
  /// Maximum recording duration in seconds.
  static const int maxDurationSeconds = 30;

  /// Maximum audio file size in bytes (4 MB).
  static const int maxFileSizeBytes = 4 * 1024 * 1024;

  /// Starts recording to a temporary file.
  ///
  /// Returns the absolute path to the temporary audio file when recording stops.
  /// The caller is responsible for deleting the file.
  ///
  /// Throws [AudioRecorderException] on hardware or permission failures.
  Future<void> startRecording();

  /// Stops recording and returns the path to the recorded audio file.
  ///
  /// Returns null if no recording data was captured or the file is empty.
  Future<String?> stopRecording();

  /// Cancels an in-progress recording and deletes any temporary file.
  Future<void> cancelRecording();

  /// Returns true if a recording is currently in progress.
  bool get isRecording;

  /// Releases all resources. Called during lifecycle disposal.
  Future<void> dispose();
}

/// Thrown when audio recording encounters a hardware or OS error.
class AudioRecorderException implements Exception {
  const AudioRecorderException(this.message);
  final String message;
  @override
  String toString() => 'AudioRecorderException: $message';
}
