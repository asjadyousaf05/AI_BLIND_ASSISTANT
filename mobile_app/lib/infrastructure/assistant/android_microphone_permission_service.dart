import 'package:flutter/services.dart';

import '../../domain/enums/microphone_permission_status.dart';
import '../../domain/services/microphone_permission_service.dart';

/// Android implementation of [MicrophonePermissionService] using [MethodChannel].
///
/// Communicates with native Android via `ai_blind_assistant/assistant_microphone`.
/// Requests RECORD_AUDIO only when triggered by user interaction.
class AndroidMicrophonePermissionService
    implements MicrophonePermissionService {
  static const _channel = MethodChannel(
    'ai_blind_assistant/assistant_microphone',
  );

  @override
  Future<MicrophonePermissionStatus> checkPermission() async {
    try {
      final statusStr = await _channel.invokeMethod<String>('checkPermission');
      return _parseStatus(statusStr);
    } on MissingPluginException {
      return MicrophonePermissionStatus.restricted;
    } catch (_) {
      return MicrophonePermissionStatus.denied;
    }
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    try {
      final statusStr = await _channel.invokeMethod<String>(
        'requestPermission',
      );
      return _parseStatus(statusStr);
    } on MissingPluginException {
      return MicrophonePermissionStatus.restricted;
    } catch (_) {
      return MicrophonePermissionStatus.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }

  MicrophonePermissionStatus _parseStatus(String? status) => switch (status) {
    'granted' => MicrophonePermissionStatus.granted,
    'permanentlyDenied' => MicrophonePermissionStatus.permanentlyDenied,
    'restricted' => MicrophonePermissionStatus.restricted,
    _ => MicrophonePermissionStatus.denied,
  };
}
