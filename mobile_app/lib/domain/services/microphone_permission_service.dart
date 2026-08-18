import '../enums/microphone_permission_status.dart';

/// Abstracts microphone permission management.
///
/// Implementations must:
/// - Request permission only after a user enables or initiates voice input.
/// - A persisted hands-free opt-in may reactivate while the app is foregrounded
///   after permission has already been granted.
/// - Handle granted, denied, permanently denied, and restricted states.
abstract interface class MicrophonePermissionService {
  /// Returns the current permission status without requesting it.
  Future<MicrophonePermissionStatus> checkPermission();

  /// Requests the RECORD_AUDIO permission.
  ///
  /// Should only be called in response to a direct user action.
  Future<MicrophonePermissionStatus> requestPermission();

  /// Opens the Android system settings for this application so the user
  /// can re-enable a permanently denied permission.
  Future<void> openAppSettings();
}
