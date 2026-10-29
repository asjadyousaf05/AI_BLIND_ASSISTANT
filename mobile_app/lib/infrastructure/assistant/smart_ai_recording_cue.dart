import 'package:flutter/services.dart';

import '../../domain/services/smart_ai_cloud_service.dart';

class SmartAiRecordingCue {
  static const _channel = MethodChannel(
    'ai_blind_assistant/smart_ai_recording_cue',
  );

  Future<void> play() async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>('play')
        .timeout(const Duration(milliseconds: 750));
    final vibration = result?['vibrationStarted'] == true;
    final chime = result?['chimeStarted'] == true;
    if (!vibration || !chime) {
      throw SmartAiCloudException(
        !vibration && !chime
            ? 'Listening vibration and sound are unavailable. Follow the Listening label or use Button controls.'
            : !vibration
            ? 'Listening vibration is unavailable. The chime and Listening label indicate when to speak.'
            : 'Listening sound is unavailable. Check media volume; the vibration and Listening label indicate when to speak.',
      );
    }
  }

  Future<void> stop() async {
    try {
      await _channel
          .invokeMethod<void>('stop')
          .timeout(const Duration(milliseconds: 750));
    } catch (_) {
      // Native feedback is independently capped and stopped on activity pause.
    }
  }
}
