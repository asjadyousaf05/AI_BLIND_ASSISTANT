import '../entities/assistant_credential.dart';

/// Stores and retrieves the assistant backend pairing credential.
///
/// Implementations must use secure, hardware-backed storage on Android.
/// The bearer token must never be logged.
abstract interface class AssistantCredentialRepository {
  /// Returns the stored credential, or null if no pairing exists.
  Future<AssistantCredential?> loadCredential();

  /// Persists [credential] in secure storage.
  Future<void> saveCredential(AssistantCredential credential);

  /// Removes the stored credential (unpairs the device).
  Future<void> deleteCredential();

  /// Returns true if a valid credential is stored.
  Future<bool> hasPairedCredential();
}
