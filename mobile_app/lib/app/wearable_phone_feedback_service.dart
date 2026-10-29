import '../domain/entities/wearable_telemetry.dart';
import '../domain/services/wearable_phone_feedback_service.dart';

typedef WearableSpeechCallback = Future<void> Function(String text);

/// Routes wearable alerts through the app's single voice/TTS owner.
class VoiceKernelWearablePhoneFeedbackService
    implements WearablePhoneFeedbackService {
  const VoiceKernelWearablePhoneFeedbackService({
    required this.speak,
    required this.stopSpeaking,
  });

  final WearableSpeechCallback speak;
  final Future<void> Function() stopSpeaking;

  @override
  Future<void> announce(WearableDetectionEvent detection) {
    return speak(detection.spokenDescription);
  }

  @override
  Future<void> testAudio() => speak(
    'Phone audio test. Raspberry Pi object alerts will play on this phone.',
  );

  @override
  Future<void> stop() => stopSpeaking();
}
