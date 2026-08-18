import 'wearable_failure.dart';
import 'wearable_settings_snapshot.dart';
import 'wearable_telemetry.dart';

sealed class WearableRepositoryEvent {
  const WearableRepositoryEvent();
}

class WearableDetectionReceived extends WearableRepositoryEvent {
  const WearableDetectionReceived(this.detection, {required this.isHazard});

  final WearableDetectionEvent detection;
  final bool isHazard;
}

class WearableStatusReceived extends WearableRepositoryEvent {
  const WearableStatusReceived(this.status);

  final WearableDeviceStatus status;
}

class WearableHealthReceived extends WearableRepositoryEvent {
  const WearableHealthReceived(this.health);

  final WearableDeviceHealth health;
}

class WearableSettingsReceived extends WearableRepositoryEvent {
  const WearableSettingsReceived(this.settings);

  final WearableSettingsSnapshot settings;
}

class WearableFailureReceived extends WearableRepositoryEvent {
  const WearableFailureReceived(this.failure);

  final WearableFailure failure;
}
