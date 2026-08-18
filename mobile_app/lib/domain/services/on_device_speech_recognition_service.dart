/// Availability details for the selected phone-local speech recognizer.
class OnDeviceSpeechAvailability {
  const OnDeviceSpeechAvailability({
    required this.available,
    required this.platformVersion,
    this.reason,
    this.provider,
    this.dedicatedAndroidAvailable = false,
    this.bundledOfflineAvailable = false,
  });

  final bool available;
  final int platformVersion;
  final String? reason;
  final String? provider;
  final bool dedicatedAndroidAvailable;
  final bool bundledOfflineAvailable;
}

/// Final transcript produced entirely on the phone.
class OnDeviceSpeechResult {
  const OnDeviceSpeechResult({required this.transcript, this.confidence});

  final String transcript;
  final double? confidence;
}

enum HandsFreeSpeechEventType { wake, command, timeout, error }

/// A bounded event from the foreground-only offline wake-word listener.
class HandsFreeSpeechEvent {
  const HandsFreeSpeechEvent({required this.type, this.transcript});

  final HandsFreeSpeechEventType type;
  final String? transcript;
}

/// Bounded push-to-talk speech recognition that must stay on the phone.
abstract interface class OnDeviceSpeechRecognitionService {
  Stream<HandsFreeSpeechEvent> get handsFreeEvents;

  Future<OnDeviceSpeechAvailability> checkAvailability();

  /// Starts an explicit user-initiated recognition session.
  Future<void> startListening({required String locale});

  /// Stops capture and waits for the final on-device transcript.
  Future<OnDeviceSpeechResult> stopListening();

  /// Cancels capture and discards any partial or final transcript.
  Future<void> cancelListening();

  /// Starts the bundled foreground wake-word loop. No network is used.
  Future<void> startHandsFree({required String locale});

  Future<void> pauseHandsFree();

  Future<void> resumeHandsFree({bool acceptNextCommand = false});

  Future<void> stopHandsFree();

  /// Sets the active Vosk recognition profile ("normal", "barge_in", "scanner_commands").
  Future<void> setRecognitionProfile(String profile);

  Future<void> dispose();
}

class OnDeviceSpeechRecognitionException implements Exception {
  const OnDeviceSpeechRecognitionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'OnDeviceSpeechRecognitionException($code): $message';
}
