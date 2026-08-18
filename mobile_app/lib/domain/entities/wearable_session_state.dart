import '../enums/wearable_assistance_state.dart';
import '../enums/wearable_connection_phase.dart';
import 'wearable_device.dart';
import 'wearable_failure.dart';
import 'wearable_settings_snapshot.dart';
import 'wearable_telemetry.dart';

class WearableSessionState {
  const WearableSessionState({
    required this.phase,
    this.selectedDevice,
    this.discoveredDevices = const [],
    this.deviceStatus,
    this.deviceHealth,
    this.cameraStatus,
    this.modelStatus,
    this.currentSettings,
    this.lastDetection,
    this.failure,
  });

  static const notConfigured = WearableSessionState(
    phase: WearableConnectionPhase.notConfigured,
  );

  static const disconnected = WearableSessionState(
    phase: WearableConnectionPhase.disconnected,
  );

  final WearableConnectionPhase phase;
  final WearableDevice? selectedDevice;
  final List<WearableDevice> discoveredDevices;
  final WearableDeviceStatus? deviceStatus;
  final WearableDeviceHealth? deviceHealth;
  final WearableComponentStatus? cameraStatus;
  final WearableComponentStatus? modelStatus;
  final WearableSettingsSnapshot? currentSettings;
  final WearableDetectionEvent? lastDetection;
  final WearableFailure? failure;

  bool get isBusy => phase.isBusy;
  bool get canStart =>
      phase == WearableConnectionPhase.connected &&
      deviceStatus?.assistanceState != WearableAssistanceState.running;
  bool get canPause => phase == WearableConnectionPhase.running;
  bool get canResume => phase == WearableConnectionPhase.paused;
  bool get canStop =>
      phase == WearableConnectionPhase.running ||
      phase == WearableConnectionPhase.paused;

  WearableSessionState copyWith({
    WearableConnectionPhase? phase,
    WearableDevice? selectedDevice,
    List<WearableDevice>? discoveredDevices,
    WearableDeviceStatus? deviceStatus,
    WearableDeviceHealth? deviceHealth,
    WearableComponentStatus? cameraStatus,
    WearableComponentStatus? modelStatus,
    WearableSettingsSnapshot? currentSettings,
    WearableDetectionEvent? lastDetection,
    WearableFailure? failure,
    bool clearSelectedDevice = false,
    bool clearFailure = false,
    bool clearTelemetry = false,
  }) {
    return WearableSessionState(
      phase: phase ?? this.phase,
      selectedDevice: clearSelectedDevice
          ? null
          : (selectedDevice ?? this.selectedDevice),
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      deviceStatus: clearTelemetry ? null : (deviceStatus ?? this.deviceStatus),
      deviceHealth: clearTelemetry ? null : (deviceHealth ?? this.deviceHealth),
      cameraStatus: clearTelemetry ? null : (cameraStatus ?? this.cameraStatus),
      modelStatus: clearTelemetry ? null : (modelStatus ?? this.modelStatus),
      currentSettings: currentSettings ?? this.currentSettings,
      lastDetection: clearTelemetry
          ? null
          : (lastDetection ?? this.lastDetection),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
