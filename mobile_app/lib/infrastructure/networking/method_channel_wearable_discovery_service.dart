import 'package:flutter/services.dart';

import '../../domain/entities/wearable_device.dart';
import '../../domain/services/wearable_discovery_service.dart';
import 'wearable_platform_exception.dart';

class MethodChannelWearableDiscoveryService
    implements WearableDiscoveryService {
  MethodChannelWearableDiscoveryService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'ai_blind_assistant/wearable';
  static const String serviceType = '_aiba-wearable._tcp';

  final MethodChannel _channel;

  @override
  Future<List<WearableDevice>> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 30)) {
      throw ArgumentError.value(timeout, 'timeout');
    }
    try {
      final result = await _channel.invokeListMethod<Object?>(
        'discoverWearableDevices',
        {'serviceType': serviceType, 'timeoutMs': timeout.inMilliseconds},
      );
      if (result == null) return const [];
      final byId = <String, WearableDevice>{};
      for (final rawDevice in result) {
        if (rawDevice is! Map) {
          throw const FormatException('Discovery result is not a map');
        }
        final device = WearableDevice.fromMap(rawDevice);
        byId[device.id] = device;
      }
      return List<WearableDevice>.unmodifiable(byId.values);
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'Wearable discovery is unavailable',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'discovery_unavailable',
        'Wearable discovery is not implemented on this platform',
      );
    }
  }

  @override
  Future<WearableDevice?> resolve(String hostOrServiceName) async {
    final target = hostOrServiceName.trim();
    if (target.isEmpty || target.length > 253) {
      throw ArgumentError.value(hostOrServiceName, 'hostOrServiceName');
    }
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'resolveWearableDevice',
        {'hostOrServiceName': target, 'serviceType': serviceType},
      );
      return result == null ? null : WearableDevice.fromMap(result);
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'The wearable hostname could not be resolved',
      );
    } on MissingPluginException {
      throw const WearablePlatformException(
        'discovery_unavailable',
        'Wearable discovery is not implemented on this platform',
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopWearableDiscovery');
    } on MissingPluginException {
      // There is no native discovery operation to stop on unsupported hosts.
    } on PlatformException catch (error) {
      throw WearablePlatformException(
        error.code,
        error.message ?? 'Wearable discovery could not be stopped',
      );
    }
  }
}
