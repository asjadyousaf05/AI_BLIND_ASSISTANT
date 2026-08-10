import '../entities/wearable_device.dart';

abstract interface class WearableDiscoveryService {
  Future<List<WearableDevice>> discover({
    Duration timeout = const Duration(seconds: 5),
  });

  /// Resolves a `.local` hostname or an mDNS service name to a current device.
  Future<WearableDevice?> resolve(String hostOrServiceName);

  Future<void> stop();
}
