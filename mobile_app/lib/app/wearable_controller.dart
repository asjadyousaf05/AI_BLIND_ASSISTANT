import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle_observer.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/wearable_device.dart';
import '../domain/entities/wearable_failure.dart';
import '../domain/entities/wearable_repository_event.dart';
import '../domain/entities/wearable_session_state.dart';
import '../domain/entities/wearable_settings_snapshot.dart';
import '../domain/enums/wearable_connection_phase.dart';
import '../domain/enums/wearable_failure_kind.dart';
import '../domain/repositories/wearable_repository.dart';
import 'providers.dart';
import 'wearable_providers.dart';

enum WearableSettingsSyncState { idle, synchronizing, synchronized, failed }

/// Presentation state for Raspberry Pi Wearable Mode.
///
/// The repository remains the source of truth for protocol and device state.
/// This wrapper adds only app-level intent, operation progress, and messages
/// which are safe to expose to assistive technologies.
class WearableControllerState {
  const WearableControllerState({
    required this.session,
    required this.liveMessage,
    this.settingsSyncState = WearableSettingsSyncState.idle,
    this.actionInProgress = false,
    this.lifecycleSuspended = false,
    this.localFailure,
  });

  final WearableSessionState session;
  final String liveMessage;
  final WearableSettingsSyncState settingsSyncState;
  final bool actionInProgress;
  final bool lifecycleSuspended;
  final WearableFailure? localFailure;

  WearableFailure? get failure => localFailure ?? session.failure;
  bool get canRunAction => !actionInProgress && !session.phase.isBusy;

  WearableControllerState copyWith({
    WearableSessionState? session,
    String? liveMessage,
    WearableSettingsSyncState? settingsSyncState,
    bool? actionInProgress,
    bool? lifecycleSuspended,
    WearableFailure? localFailure,
    bool clearLocalFailure = false,
  }) {
    return WearableControllerState(
      session: session ?? this.session,
      liveMessage: liveMessage ?? this.liveMessage,
      settingsSyncState: settingsSyncState ?? this.settingsSyncState,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      lifecycleSuspended: lifecycleSuspended ?? this.lifecycleSuspended,
      localFailure: clearLocalFailure
          ? null
          : (localFailure ?? this.localFailure),
    );
  }
}

final wearableControllerProvider =
    NotifierProvider<WearableController, WearableControllerState>(
      WearableController.new,
    );

class WearableController extends Notifier<WearableControllerState> {
  StreamSubscription<WearableSessionState>? _stateSubscription;
  StreamSubscription<WearableRepositoryEvent>? _eventSubscription;
  AppLifecycleObserver? _lifecycleObserver;
  bool _disposed = false;
  bool _connectionDesired = false;
  bool _foreground = true;
  bool _settingsSyncInProgress = false;
  int _settingsRevision = 0;
  DateTime _settingsUpdatedAt = DateTime.now().toUtc();

  WearableRepository get _repository => ref.read(wearableRepositoryProvider);

  @override
  WearableControllerState build() {
    final repository = ref.read(wearableRepositoryProvider);
    _stateSubscription = repository.states.listen(_handleRepositoryState);
    _eventSubscription = repository.events.listen(_handleRepositoryEvent);
    _lifecycleObserver = AppLifecycleObserver(
      onStateChanged: (lifecycleState) {
        unawaited(handleLifecycleChange(lifecycleState));
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    ref.listen<AppSettings>(appSettingsControllerProvider, (previous, next) {
      if (previous == next) return;
      _settingsRevision++;
      _settingsUpdatedAt = DateTime.now().toUtc();
      if (state.session.phase.isConnected) {
        unawaited(synchronizeSettings());
      }
    });
    ref.onDispose(_disposeController);

    final initial = repository.state;
    _connectionDesired = initial.phase.isConnected;
    unawaited(Future<void>.microtask(_initializeRepository));
    return WearableControllerState(
      session: initial,
      liveMessage: statusLabelFor(initial.phase),
    );
  }

  Future<void> discover() async {
    if (!_beginAction('Searching the local network for a wearable')) return;
    try {
      final devices = await _repository.discover();
      _refreshFromRepository();
      if (devices.isEmpty) {
        _setLiveMessage(
          'No wearable found. Check local Wi-Fi or enter its address manually.',
        );
      } else {
        _setLiveMessage(
          devices.length == 1
              ? 'One wearable found'
              : '${devices.length} wearables found',
        );
      }
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.discovery,
        'discovery_failed',
        'The wearable search failed. Check local Wi-Fi and try again.',
        error,
      );
    } finally {
      _endAction();
    }
  }

  void selectDevice(WearableDevice device) {
    if (state.actionInProgress || state.session.phase.isBusy) return;
    _repository.selectDevice(device);
    _refreshFromRepository();
    state = state.copyWith(
      liveMessage: '${device.name} selected. Pair it to continue.',
      clearLocalFailure: true,
    );
  }

  /// Validates and selects a manually entered local hostname or IP address.
  /// Returns a user-facing validation error, or `null` on success.
  String? selectManualDevice({required String host, required String port}) {
    final hostError = validateHost(host);
    if (hostError != null) return hostError;
    final portError = validatePort(port);
    if (portError != null) return portError;

    final normalizedHost = host.trim();
    final parsedPort = int.parse(port.trim());
    selectDevice(
      WearableDevice(
        id: 'manual:$normalizedHost:$parsedPort',
        name: normalizedHost,
        host: normalizedHost,
        port: parsedPort,
        source: WearableDeviceSource.manual,
      ),
    );
    return null;
  }

  Future<void> pair(String pairingCode) async {
    final codeError = validatePairingCode(pairingCode);
    if (codeError != null) {
      _recordValidationFailure(codeError);
      return;
    }
    if (!_beginAction('Pairing with the selected wearable')) return;
    try {
      await _repository.pair(pairingCode.trim().toUpperCase());
      _refreshFromRepository();
      _setLiveMessage('Pairing succeeded. The wearable is ready to connect.');
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.authentication,
        'pairing_failed',
        'Pairing failed. Check the code and request a fresh code if it expired.',
        error,
      );
    } finally {
      _endAction();
    }
  }

  Future<void> connect() async {
    if (state.session.selectedDevice == null) {
      _recordValidationFailure(
        'Select a discovered wearable or enter its local address first.',
      );
      return;
    }
    if (!_beginAction('Connecting securely to the wearable')) return;
    _connectionDesired = true;
    try {
      await _repository.connect();
      _refreshFromRepository();
      if (_repository.state.phase.isConnected) {
        await synchronizeSettings(force: true);
        _setLiveMessage('Wearable connected and settings synchronized.');
      }
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.network,
        'connection_failed',
        'The wearable could not be reached on the local network.',
        error,
      );
    } finally {
      _endAction();
    }
  }

  Future<void> disconnect() async {
    if (!_beginAction('Disconnecting from the wearable')) return;
    _connectionDesired = false;
    try {
      await _repository.disconnect();
      _refreshFromRepository();
      _setLiveMessage(
        'Phone disconnected. Active assistance on the wearable was not stopped.',
      );
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.network,
        'disconnect_failed',
        'The phone could not close the wearable connection cleanly.',
        error,
      );
    } finally {
      _endAction();
    }
  }

  Future<void> startAssistance() => _runDeviceCommand(
    liveMessage: 'Starting wearable assistance',
    successMessage: 'Wearable assistance started',
    operation: _repository.startAssistance,
  );

  Future<void> pauseAssistance() => _runDeviceCommand(
    liveMessage: 'Pausing wearable assistance',
    successMessage: 'Wearable assistance paused',
    operation: _repository.pauseAssistance,
  );

  Future<void> resumeAssistance() => _runDeviceCommand(
    liveMessage: 'Resuming wearable assistance',
    successMessage: 'Wearable assistance resumed',
    operation: _repository.resumeAssistance,
  );

  Future<void> stopAssistance() => _runDeviceCommand(
    liveMessage: 'Stopping wearable assistance',
    successMessage: 'Wearable assistance stopped',
    operation: _repository.stopAssistance,
  );

  Future<void> changeMode(String mode) async {
    final normalized = mode.trim();
    if (normalized.isEmpty) {
      _recordValidationFailure('Select a valid assistance mode.');
      return;
    }
    await _runDeviceCommand(
      liveMessage: 'Changing wearable assistance mode',
      successMessage: 'Wearable mode changed',
      operation: () => _repository.changeMode(normalized),
    );
  }

  Future<void> synchronizeSettings({bool force = false}) async {
    if (_settingsSyncInProgress || !state.session.phase.isConnected) return;
    if (!force && state.actionInProgress) return;

    _settingsSyncInProgress = true;
    state = state.copyWith(
      settingsSyncState: WearableSettingsSyncState.synchronizing,
      liveMessage: 'Synchronizing wearable settings',
    );
    try {
      final appSettings = ref.read(appSettingsControllerProvider);
      final clientId = await ref.read(wearableClientIdProvider.future);
      final remoteRevision =
          state.session.currentSettings?.version.revision ?? 0;
      _settingsRevision = math.max(_settingsRevision, remoteRevision + 1);
      final snapshot = WearableSettingsSnapshot(
        version: WearableSettingsVersion(
          revision: _settingsRevision,
          updatedAt: _settingsUpdatedAt,
          source: WearableSettingsSource.phone,
          sourceId: clientId,
        ),
        confidenceThreshold: appSettings.detectionSettings.confidenceThreshold,
        announcementCooldownSeconds:
            appSettings.feedbackSettings.announcementCooldownSeconds,
        speechEnabled: appSettings.feedbackSettings.audioEnabled,
        vibrationEnabled:
            appSettings.vibrationEnabled &&
            appSettings.feedbackSettings.vibrationEnabled,
        assistanceMode:
            state.session.deviceStatus?.assistanceMode ?? 'object_detection',
      );
      await _repository.updateSettings(snapshot);
      _refreshFromRepository();
      state = state.copyWith(
        settingsSyncState: WearableSettingsSyncState.synchronized,
        liveMessage: 'Wearable settings synchronized',
        clearLocalFailure: true,
      );
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.device,
        'settings_sync_failed',
        'Settings were not synchronized. The previous Pi settings remain active.',
        error,
      );
      state = state.copyWith(
        settingsSyncState: WearableSettingsSyncState.failed,
      );
    } finally {
      _settingsSyncInProgress = false;
    }
  }

  Future<void> retry() async {
    final failureKind = state.failure?.kind;
    if (failureKind == WearableFailureKind.pairingExpired ||
        failureKind == WearableFailureKind.authentication) {
      _setLiveMessage(
        'Enter a fresh pairing code, or forget the revoked credential and pair again.',
      );
      return;
    }
    if (state.session.selectedDevice == null) {
      await discover();
    } else {
      await connect();
    }
  }

  Future<void> forgetDevice() async {
    if (!_beginAction('Forgetting the paired wearable')) return;
    _connectionDesired = false;
    try {
      await _repository.forgetDevice();
      _refreshFromRepository();
      _setLiveMessage(
        'Wearable forgotten. Its phone credential has been removed.',
      );
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.storage,
        'forget_failed',
        'The saved wearable credential could not be removed.',
        error,
      );
    } finally {
      _endAction();
    }
  }

  /// Disconnects only the phone transport when backgrounded. It deliberately
  /// does not send `stop_assistance`, so the Pi can keep providing local
  /// feedback. A previously desired connection is restored once on resume.
  @visibleForTesting
  Future<void> handleLifecycleChange(AppLifecycleState lifecycleState) async {
    switch (lifecycleState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_foreground) return;
        _foreground = false;
        final shouldDisconnect =
            state.session.phase.isConnected || state.session.phase.isBusy;
        state = state.copyWith(
          lifecycleSuspended: true,
          liveMessage:
              'App in background. Phone connection paused; wearable assistance continues locally.',
        );
        if (shouldDisconnect) {
          try {
            await _repository.disconnect();
            _refreshFromRepository(lifecycleSuspended: true);
          } on Object catch (error) {
            _recordActionFailure(
              WearableFailureKind.network,
              'background_disconnect_failed',
              'The app could not close the background connection cleanly.',
              error,
            );
          }
        }
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        state = state.copyWith(
          lifecycleSuspended: false,
          liveMessage: _connectionDesired
              ? 'App resumed. Reconnecting to the wearable.'
              : 'App resumed. Wearable remains disconnected.',
        );
        if (_connectionDesired && state.session.selectedDevice != null) {
          await connect();
        }
    }
  }

  static String? validateHost(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Enter the Raspberry Pi hostname or IP address.';
    if (value.length > 253 ||
        value.contains(RegExp(r'[\s/@?#]')) ||
        value.contains('://')) {
      return 'Enter only a local hostname or IP address, without a URL path.';
    }

    final address = InternetAddress.tryParse(value);
    if (address != null) {
      if (!_isLocalAddress(address)) {
        return 'Enter a private-LAN or loopback IP address.';
      }
      return null;
    }
    if (RegExp(r'^\d+(\.\d+){3}$').hasMatch(value)) {
      return 'Enter a valid IPv4 address.';
    }
    final labels = value.endsWith('.')
        ? value.substring(0, value.length - 1).split('.')
        : value.split('.');
    final hostnameLabel = RegExp(
      r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
    );
    if (labels.isEmpty ||
        labels.any((label) => !hostnameLabel.hasMatch(label))) {
      return 'Enter a valid hostname, such as rpi3-ml.local.';
    }
    final normalized = value.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (labels.length > 1 &&
        !normalized.endsWith('.local') &&
        !normalized.endsWith('.lan')) {
      return 'Enter a local hostname, such as rpi3-ml.local.';
    }
    return null;
  }

  static bool _isLocalAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return bytes[0] == 10 ||
          bytes[0] == 127 ||
          (bytes[0] == 169 && bytes[1] == 254) ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168);
    }
    return address.isLoopback ||
        (bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
  }

  static String? validatePort(String? rawValue) {
    final parsed = int.tryParse(rawValue?.trim() ?? '');
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return 'Enter a port from 1 to 65535.';
    }
    return null;
  }

  static String? validatePairingCode(String? rawValue) {
    final value = rawValue?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$').hasMatch(value)) {
      return 'Enter the current eight-character pairing code shown by the Pi.';
    }
    return null;
  }

  static String statusLabelFor(WearableConnectionPhase phase) {
    return switch (phase) {
      WearableConnectionPhase.notConfigured => 'No wearable configured',
      WearableConnectionPhase.disconnected => 'Wearable disconnected',
      WearableConnectionPhase.discovering => 'Searching for wearable',
      WearableConnectionPhase.deviceFound => 'Wearable found',
      WearableConnectionPhase.pairing => 'Pairing in progress',
      WearableConnectionPhase.paired => 'Wearable paired',
      WearableConnectionPhase.connecting => 'Connecting to wearable',
      WearableConnectionPhase.authenticating =>
        'Authenticating local connection',
      WearableConnectionPhase.connected => 'Wearable connected',
      WearableConnectionPhase.reconnecting => 'Reconnecting to wearable',
      WearableConnectionPhase.starting => 'Starting wearable assistance',
      WearableConnectionPhase.running => 'Wearable assistance running',
      WearableConnectionPhase.paused => 'Wearable assistance paused',
      WearableConnectionPhase.stopping => 'Stopping wearable assistance',
      WearableConnectionPhase.incompatible =>
        'App and wearable protocol versions are incompatible',
      WearableConnectionPhase.authenticationFailed =>
        'Wearable authentication failed',
      WearableConnectionPhase.unavailable => 'Wearable unavailable',
      WearableConnectionPhase.error => 'Wearable connection error',
    };
  }

  static String recoveryMessageFor(WearableFailure? failure) {
    if (failure == null) {
      return 'Check that the Pi is powered, on the same local network, and its wearable service is running.';
    }
    return switch (failure.kind) {
      WearableFailureKind.discovery =>
        'Put the phone and Pi on the same local Wi-Fi. Search again, or enter the Pi hostname or current IP address.',
      WearableFailureKind.network || WearableFailureKind.timeout =>
        'Check Pi power, local Wi-Fi, and the wearable service. Then retry; internet access is not required.',
      WearableFailureKind.authentication =>
        'The saved credential was rejected or revoked. Forget this device, generate a new Pi pairing code, and pair again.',
      WearableFailureKind.pairingExpired =>
        'Generate a fresh short-lived code on the Pi and enter it before it expires.',
      WearableFailureKind.incompatibleProtocol =>
        'Install compatible app and Pi service versions. Connections are blocked until their protocol versions match.',
      WearableFailureKind.malformedMessage =>
        'Restart the app and Pi service. If this repeats, verify both use the same documented protocol version.',
      WearableFailureKind.camera =>
        'Inspect the CSI cable and camera service logs. The OV5647 can time out and may require a hardware check.',
      WearableFailureKind.model =>
        'Verify the NCNN parameter, binary, labels, and metadata files on the Pi, then restart its service.',
      WearableFailureKind.device =>
        'Check the device health details and Pi service logs before retrying.',
      WearableFailureKind.storage =>
        'Secure local storage failed. Restart the app and retry; do not remove Pi files manually.',
      WearableFailureKind.unknown =>
        'Retry once. If it fails again, inspect the app and Pi service logs for the reported error code.',
    };
  }

  Future<void> _runDeviceCommand({
    required String liveMessage,
    required String successMessage,
    required Future<void> Function() operation,
  }) async {
    if (!state.session.phase.isConnected) {
      _recordValidationFailure(
        'Connect to the wearable before using controls.',
      );
      return;
    }
    if (!_beginAction(liveMessage)) return;
    _connectionDesired = true;
    try {
      await operation();
      _refreshFromRepository();
      _setLiveMessage(successMessage);
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.device,
        'command_failed',
        'The wearable did not confirm the requested command.',
        error,
      );
    } finally {
      _endAction();
    }
  }

  Future<void> _initializeRepository() async {
    try {
      await _repository.initialize();
      _refreshFromRepository();
      final restored = _repository.state.selectedDevice;
      if (restored != null &&
          _repository.state.phase == WearableConnectionPhase.paired) {
        _setLiveMessage(
          '${restored.name} restored securely. Connect when the Pi is available.',
        );
      }
    } on Object catch (error) {
      _recordActionFailure(
        WearableFailureKind.storage,
        'wearable_restore_failed',
        'The saved wearable could not be restored from secure storage.',
        error,
      );
    }
  }

  bool _beginAction(String liveMessage) {
    if (state.actionInProgress || state.session.phase.isBusy) return false;
    state = state.copyWith(
      actionInProgress: true,
      liveMessage: liveMessage,
      clearLocalFailure: true,
    );
    return true;
  }

  void _endAction() {
    if (_disposed) return;
    state = state.copyWith(actionInProgress: false);
  }

  void _handleRepositoryState(WearableSessionState next) {
    if (_disposed) return;
    final previous = state.session;
    final phaseChanged = previous.phase != next.phase;
    state = state.copyWith(
      session: next,
      liveMessage: phaseChanged
          ? statusLabelFor(next.phase)
          : state.liveMessage,
      clearLocalFailure: next.failure == null,
    );

    if (next.phase.isConnected) {
      _connectionDesired = true;
      if (!previous.phase.isConnected && !state.actionInProgress) {
        unawaited(synchronizeSettings(force: true));
      }
      return;
    }
  }

  void _handleRepositoryEvent(WearableRepositoryEvent event) {
    if (_disposed) return;
    switch (event) {
      case WearableFailureReceived(:final failure):
        state = state.copyWith(
          localFailure: failure,
          liveMessage: failure.userMessage,
        );
      case WearableSettingsReceived():
        state = state.copyWith(
          settingsSyncState: WearableSettingsSyncState.synchronized,
        );
      case WearableDetectionReceived():
        // The Pi owns default speech/haptics. Detection events remain visible
        // in the UI, but are intentionally not announced by the phone because
        // protocol v1 has no explicit phone-feedback permission flag.
        break;
      case WearableStatusReceived():
      case WearableHealthReceived():
        break;
    }
  }

  void _refreshFromRepository({bool? lifecycleSuspended}) {
    if (_disposed) return;
    state = state.copyWith(
      session: _repository.state,
      lifecycleSuspended: lifecycleSuspended,
      clearLocalFailure: _repository.state.failure == null,
    );
  }

  void _setLiveMessage(String message) {
    if (_disposed) return;
    state = state.copyWith(liveMessage: message);
  }

  void _recordValidationFailure(String message) {
    if (_disposed) return;
    state = state.copyWith(
      localFailure: WearableFailure(
        kind: WearableFailureKind.unknown,
        code: 'invalid_input',
        userMessage: message,
        canRetry: false,
      ),
      liveMessage: message,
    );
  }

  void _recordActionFailure(
    WearableFailureKind kind,
    String code,
    String message,
    Object error,
  ) {
    if (_disposed) return;
    debugPrint('Wearable action failed ($code): ${error.runtimeType}');
    state = state.copyWith(
      localFailure: WearableFailure(
        kind: kind,
        code: code,
        userMessage: message,
      ),
      liveMessage: message,
    );
  }

  void _disposeController() {
    _disposed = true;
    unawaited(_stateSubscription?.cancel());
    unawaited(_eventSubscription?.cancel());
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }
}
