import '../entities/wearable_device.dart';
import '../entities/wearable_repository_event.dart';
import '../entities/wearable_session_state.dart';
import '../entities/wearable_settings_snapshot.dart';

abstract interface class WearableRepository {
  WearableSessionState get state;

  Stream<WearableSessionState> get states;

  Stream<WearableRepositoryEvent> get events;

  /// Restores the last paired endpoint and credential-backed configuration.
  Future<void> initialize();

  Future<List<WearableDevice>> discover();

  void selectDevice(WearableDevice device);

  Future<void> pair(String pairingCode);

  Future<void> connect();

  Future<void> startAssistance();

  Future<void> pauseAssistance();

  Future<void> resumeAssistance();

  Future<void> stopAssistance();

  Future<void> changeMode(String mode);

  Future<void> updateSettings(WearableSettingsSnapshot settings);

  Future<void> requestCurrentSettings();

  Future<void> disconnect();

  Future<void> forgetDevice();

  Future<void> dispose();
}
