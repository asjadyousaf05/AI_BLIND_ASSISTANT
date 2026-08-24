import '../entities/wearable_telemetry.dart';

/// Announces authenticated Raspberry Pi hazard events through the phone.
abstract interface class WearablePhoneFeedbackService {
  Future<void> announce(WearableDetectionEvent detection);
}
