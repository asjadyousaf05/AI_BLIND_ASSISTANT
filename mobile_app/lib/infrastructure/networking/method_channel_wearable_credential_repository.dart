import 'package:flutter/services.dart';

import '../../domain/entities/wearable_credential.dart';
import '../../domain/repositories/wearable_credential_repository.dart';
import 'wearable_platform_exception.dart';

class MethodChannelWearableCredentialRepository
    implements WearableCredentialRepository {
  MethodChannelWearableCredentialRepository({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'ai_blind_assistant/wearable';
  final MethodChannel _channel;

  @override
  Future<String> getOrCreateClientId() async {
    try {
      final clientId = await _channel.invokeMethod<String>(
        'getOrCreateWearableClientId',
      );
      if (clientId == null || clientId.isEmpty || clientId.length > 128) {
        throw const WearablePlatformException(
          'invalid_client_id',
          'Secure storage returned an invalid wearable client identifier',
        );
      }
      return clientId;
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'The wearable client identifier is unavailable',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'secure_storage_unavailable',
        'Secure wearable identity storage is unavailable',
      );
    }
  }

  @override
  Future<WearableCredential?> read(String deviceId) async {
    _validateDeviceId(deviceId);
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'readWearableCredential',
        {'deviceId': deviceId},
      );
      return result == null ? null : WearableCredential.fromSecureMap(result);
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'The wearable credential could not be read',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'secure_storage_unavailable',
        'Secure wearable credential storage is unavailable',
      );
    }
  }

  @override
  Future<WearableCredential?> readLastPaired() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'readLastWearableCredential',
      );
      return result == null ? null : WearableCredential.fromSecureMap(result);
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'The saved wearable device could not be restored',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'secure_storage_unavailable',
        'Secure wearable credential storage is unavailable',
      );
    }
  }

  @override
  Future<void> write(WearableCredential credential) async {
    _validateDeviceId(credential.deviceId);
    try {
      await _channel.invokeMethod<void>(
        'writeWearableCredential',
        credential.toSecureMap(),
      );
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'The wearable credential could not be stored securely',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'secure_storage_unavailable',
        'Secure wearable credential storage is unavailable',
      );
    }
  }

  @override
  Future<void> delete(String deviceId) async {
    _validateDeviceId(deviceId);
    try {
      await _channel.invokeMethod<void>('deleteWearableCredential', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'The wearable credential could not be removed',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'secure_storage_unavailable',
        'Secure wearable credential storage is unavailable',
      );
    }
  }

  void _validateDeviceId(String deviceId) {
    if (deviceId.isEmpty || deviceId.length > 128) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
  }
}
