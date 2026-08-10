import 'package:flutter/services.dart';

import '../../domain/enums/camera_permission_status.dart';
import '../../domain/services/permission_service.dart';

/// Uses Android-specific method channels to manage camera permission
/// without requiring the permission_handler pub package.
///
/// When running in tests or on platforms without the native side,
/// calls safely return [CameraPermissionStatus.unknown] or false.
class AndroidPermissionService implements PermissionService {
  AndroidPermissionService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('ai_blind_assistant/permissions');

  final MethodChannel _channel;

  @override
  Future<CameraPermissionStatus> checkCameraPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('checkCamera');
      return _parseStatus(result);
    } on MissingPluginException {
      return CameraPermissionStatus.unknown;
    } catch (_) {
      return CameraPermissionStatus.unknown;
    }
  }

  @override
  Future<CameraPermissionStatus> requestCameraPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestCamera');
      return _parseStatus(result);
    } on MissingPluginException {
      return CameraPermissionStatus.unknown;
    } catch (_) {
      return CameraPermissionStatus.unknown;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openSettings');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  CameraPermissionStatus _parseStatus(String? status) {
    return switch (status) {
      'granted' => CameraPermissionStatus.granted,
      'denied' => CameraPermissionStatus.denied,
      'permanentlyDenied' => CameraPermissionStatus.permanentlyDenied,
      'restricted' => CameraPermissionStatus.restricted,
      _ => CameraPermissionStatus.unknown,
    };
  }
}
