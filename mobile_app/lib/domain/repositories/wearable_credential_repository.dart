import '../entities/wearable_credential.dart';

abstract interface class WearableCredentialRepository {
  /// Returns a stable, non-secret random installation identifier. It is kept
  /// by the platform implementation and is not a hardcoded shared identity.
  Future<String> getOrCreateClientId();

  Future<WearableCredential?> read(String deviceId);

  Future<WearableCredential?> readLastPaired();

  Future<void> write(WearableCredential credential);

  Future<void> delete(String deviceId);
}
