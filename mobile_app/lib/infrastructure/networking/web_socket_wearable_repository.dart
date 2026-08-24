// ignore_for_file: prefer_initializing_formals, use_null_aware_elements

import 'dart:async';
import 'dart:convert';

import '../../domain/entities/protocol_envelope.dart';
import '../../domain/entities/wearable_credential.dart';
import '../../domain/entities/wearable_device.dart';
import '../../domain/entities/wearable_failure.dart';
import '../../domain/entities/wearable_repository_event.dart';
import '../../domain/entities/wearable_session_state.dart';
import '../../domain/entities/wearable_settings_snapshot.dart';
import '../../domain/entities/wearable_telemetry.dart';
import '../../domain/enums/protocol_message_type.dart';
import '../../domain/enums/wearable_assistance_state.dart';
import '../../domain/enums/wearable_connection_phase.dart';
import '../../domain/enums/wearable_failure_kind.dart';
import '../../domain/enums/wearable_transport_status.dart';
import '../../domain/repositories/wearable_credential_repository.dart';
import '../../domain/repositories/wearable_repository.dart';
import '../../domain/services/wearable_discovery_service.dart';
import '../../domain/services/wearable_transport.dart';
import 'bounded_retry_policy.dart';
import 'protocol_exception.dart';
import 'protocol_message_factory.dart';
import 'sequence_deduplicator.dart';
import 'wearable_authenticator.dart';
import 'wearable_settings_resolver.dart';

class WebSocketWearableRepository implements WearableRepository {
  WebSocketWearableRepository({
    required WearableDiscoveryService discoveryService,
    required WearableCredentialRepository credentialRepository,
    required WearableTransport transport,
    this.clientName = 'AI Blind Assistant',
    ProtocolMessageFactory? messageFactory,
    WearableAuthenticator authenticator = const WearableAuthenticator(),
    BoundedRetryPolicy? retryPolicy,
    SequenceDeduplicator? deduplicator,
    WearableSettingsResolver settingsResolver =
        const WearableSettingsResolver(),
    this.handshakeTimeout = const Duration(seconds: 8),
  }) : _discoveryService = discoveryService,
       _credentialRepository = credentialRepository,
       _transport = transport,
       _messageFactory = messageFactory ?? ProtocolMessageFactory(),
       _authenticator = authenticator,
       _retryPolicy = retryPolicy ?? BoundedRetryPolicy(),
       _deduplicator = deduplicator ?? SequenceDeduplicator(),
       _settingsResolver = settingsResolver {
    _messageSubscription = _transport.messages.listen(
      _handleMessage,
      onError: _handleTransportError,
    );
    _statusSubscription = _transport.statuses.listen(_handleTransportStatus);
  }

  final WearableDiscoveryService _discoveryService;
  final WearableCredentialRepository _credentialRepository;
  final WearableTransport _transport;
  final ProtocolMessageFactory _messageFactory;
  final WearableAuthenticator _authenticator;
  final BoundedRetryPolicy _retryPolicy;
  final SequenceDeduplicator _deduplicator;
  final WearableSettingsResolver _settingsResolver;
  final String clientName;
  final Duration handshakeTimeout;

  final StreamController<WearableSessionState> _stateController =
      StreamController<WearableSessionState>.broadcast();
  final StreamController<WearableRepositoryEvent> _eventController =
      StreamController<WearableRepositoryEvent>.broadcast();

  late final StreamSubscription<ProtocolEnvelope> _messageSubscription;
  late final StreamSubscription<WearableTransportStatus> _statusSubscription;
  WearableSessionState _state = WearableSessionState.notConfigured;
  WearableCredential? _activeCredential;
  String? _remoteSessionSource;
  Future<void>? _initializeFuture;
  bool _connectionOperation = false;
  bool _intentionalDisconnect = false;
  bool _authenticationRejected = false;
  bool _reconnectInProgress = false;
  bool _disposed = false;

  @override
  WearableSessionState get state => _state;

  @override
  Stream<WearableSessionState> get states => _stateController.stream;

  @override
  Stream<WearableRepositoryEvent> get events => _eventController.stream;

  @override
  Future<void> initialize() {
    _ensureUsable();
    return _initializeFuture ??= _restoreSavedDevice();
  }

  Future<void> _restoreSavedDevice() async {
    try {
      final credential = await _credentialRepository.readLastPaired();
      if (credential == null) {
        _emit(
          _state.copyWith(
            phase: WearableConnectionPhase.notConfigured,
            clearSelectedDevice: true,
            clearFailure: true,
          ),
        );
        return;
      }
      _activeCredential = credential;
      _emit(
        _state.copyWith(
          phase: WearableConnectionPhase.paired,
          selectedDevice: credential.toDevice(),
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      _reportFailure(
        _classify(error, fallbackKind: WearableFailureKind.storage),
        phase: WearableConnectionPhase.unavailable,
      );
    }
  }

  @override
  Future<List<WearableDevice>> discover() async {
    _ensureUsable();
    _emit(
      _state.copyWith(
        phase: WearableConnectionPhase.discovering,
        clearFailure: true,
      ),
    );
    try {
      final devices = await _discoveryService.discover();
      final selected = _state.selectedDevice;
      final merged = <String, WearableDevice>{
        if (selected != null) selected.id: selected,
        for (final device in devices) device.id: device,
      }.values.toList(growable: false);
      _emit(
        _state.copyWith(
          phase: merged.isEmpty
              ? WearableConnectionPhase.notConfigured
              : WearableConnectionPhase.deviceFound,
          discoveredDevices: merged,
          clearFailure: true,
        ),
      );
      return merged;
    } on Object catch (error) {
      _reportFailure(
        _classify(error, fallbackKind: WearableFailureKind.discovery),
        phase: WearableConnectionPhase.unavailable,
      );
      rethrow;
    }
  }

  @override
  void selectDevice(WearableDevice device) {
    _ensureUsable();
    _emit(
      _state.copyWith(
        phase: WearableConnectionPhase.deviceFound,
        selectedDevice: device,
        clearFailure: true,
      ),
    );
  }

  @override
  Future<void> enroll() => _issueCredential(
    phase: WearableConnectionPhase.enrolling,
    requestType: ProtocolMessageType.enrollmentRequest,
    resultType: ProtocolMessageType.enrollmentResult,
    successField: 'enrolled',
    disconnectReason: 'trusted_enrollment',
    payloadForClient: (clientId) => {
      'clientId': clientId,
      'clientName': clientName,
    },
  );

  @override
  Future<void> pair(String pairingCode) async {
    _ensureUsable();
    if (!RegExp(
      r'^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$',
    ).hasMatch(pairingCode)) {
      throw ArgumentError.value(
        pairingCode.length,
        'pairingCode',
        'Pairing code must contain eight valid characters',
      );
    }
    await _issueCredential(
      phase: WearableConnectionPhase.pairing,
      requestType: ProtocolMessageType.pairRequest,
      resultType: ProtocolMessageType.pairResult,
      successField: 'paired',
      disconnectReason: 'pairing',
      payloadForClient: (clientId) => {
        'clientId': clientId,
        'clientName': clientName,
        'pairingCode': pairingCode,
      },
    );
  }

  Future<void> _issueCredential({
    required WearableConnectionPhase phase,
    required ProtocolMessageType requestType,
    required ProtocolMessageType resultType,
    required String successField,
    required String disconnectReason,
    required Map<String, Object?> Function(String clientId) payloadForClient,
  }) async {
    _ensureUsable();
    var selected = _state.selectedDevice;
    if (selected == null) {
      throw StateError('Select a wearable device before enrollment');
    }
    _beginConnectionOperation();
    _intentionalDisconnect = true;
    _authenticationRejected = false;
    _emit(_state.copyWith(phase: phase, clearFailure: true));
    try {
      selected = await _resolveLocalEndpoint(selected);
      _emit(_state.copyWith(selectedDevice: selected));
      await _transport.disconnect(reason: 'begin_$disconnectReason');
      _transport.clearAuthentication();
      final helloFuture = _nextMessage(ProtocolMessageType.hello);
      await _transport.connect(selected.webSocketUri);
      final hello = await helloFuture;
      final actualDevice = _deviceFromHello(selected, hello);
      if (requestType == ProtocolMessageType.enrollmentRequest) {
        final capabilities = hello.payload['capabilities'];
        final supportsEnrollment =
            capabilities is List &&
            capabilities.contains('exclusive_first_client_enrollment');
        if (!supportsEnrollment) {
          throw WearableRemoteException(
            code: hello.payload['paired'] == true
                ? 'enrollment_closed'
                : 'enrollment_disabled',
            message: hello.payload['paired'] == true
                ? 'Another phone is already enrolled. Reset trusted phones on the Pi before enrolling this phone.'
                : 'Code-free enrollment is disabled on this Pi service.',
            retryable: false,
          );
        }
      }
      final clientId = await _credentialRepository.getOrCreateClientId();
      final request = _messageFactory.create(
        requestType,
        payload: payloadForClient(clientId),
      );
      final resultFuture = _nextMessage(
        resultType,
        predicate: (message) =>
            message.payload['requestMessageId'] == request.messageId,
      );
      await _transport.send(request, requireAcknowledgement: false);
      final result = await resultFuture;
      if (result.payload[successField] != true) {
        final code =
            (result.payload['errorCode'] as String?) ??
            '${disconnectReason}_failed';
        throw WearableRemoteException(
          code: code,
          message: code == 'enrollment_closed'
              ? 'Another phone is already enrolled. Reset trusted phones on the Pi before enrolling this phone.'
              : 'The wearable did not issue a trusted phone credential.',
          retryable: code != 'enrollment_closed',
          requestMessageId: request.messageId,
        );
      }
      final deviceId = result.payload['deviceId']! as String;
      final credentialId = result.payload['credentialId']! as String;
      final secret = result.payload['credentialSecret']! as String;
      _requireStrongCredentialSecret(secret);
      final authoritativeDevice = actualDevice.copyWith(id: deviceId);
      final credential = WearableCredential(
        deviceId: deviceId,
        deviceName: authoritativeDevice.name,
        host: authoritativeDevice.host,
        port: authoritativeDevice.port,
        serviceName: authoritativeDevice.serviceName,
        clientId: clientId,
        credentialId: credentialId,
        secret: secret,
        createdAt: DateTime.now().toUtc(),
      );
      await _credentialRepository.write(credential);
      _activeCredential = credential;
      await _transport.disconnect(reason: '${disconnectReason}_complete');
      _emit(
        _state.copyWith(
          phase: WearableConnectionPhase.paired,
          selectedDevice: authoritativeDevice,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      await _transport.disconnect(reason: '${disconnectReason}_failed');
      final failure = _classify(
        error,
        fallbackKind: WearableFailureKind.authentication,
      );
      _reportFailure(
        failure,
        phase: requestType == ProtocolMessageType.enrollmentRequest
            ? WearableConnectionPhase.deviceFound
            : failure.kind == WearableFailureKind.pairingExpired
            ? WearableConnectionPhase.authenticationFailed
            : WearableConnectionPhase.error,
      );
      rethrow;
    } finally {
      _connectionOperation = false;
      _intentionalDisconnect = false;
    }
  }

  @override
  Future<void> connect() async {
    await initialize();
    _ensureUsable();
    if (_connectionOperation) {
      throw StateError('A wearable connection operation is already active');
    }
    var selected = _state.selectedDevice;
    if (selected == null) {
      _emit(_state.copyWith(phase: WearableConnectionPhase.notConfigured));
      throw StateError('No paired wearable device is configured');
    }
    final credential =
        _activeCredential ?? await _credentialRepository.read(selected.id);
    if (credential == null) {
      _emit(_state.copyWith(phase: WearableConnectionPhase.notConfigured));
      throw StateError('The selected wearable device has not been paired');
    }
    _activeCredential = credential;
    selected = await _refreshEndpoint(credential, selected);
    _emit(_state.copyWith(selectedDevice: selected));
    await _connectWithCredential(
      credential,
      selected,
      reconnecting: _state.phase == WearableConnectionPhase.unavailable,
    );
  }

  Future<void> _connectWithCredential(
    WearableCredential credential,
    WearableDevice device, {
    required bool reconnecting,
  }) async {
    _beginConnectionOperation();
    _intentionalDisconnect = false;
    _authenticationRejected = false;
    try {
      await _retryPolicy.execute<void>(
        (_) => _connectOnce(credential, device, reconnecting: reconnecting),
        shouldRetry: _shouldRetryConnection,
      );
    } on Object catch (error) {
      final failure = _classify(error);
      _reportFailure(failure, phase: _phaseForFailure(failure));
      rethrow;
    } finally {
      _connectionOperation = false;
    }
  }

  Future<void> _connectOnce(
    WearableCredential credential,
    WearableDevice device, {
    required bool reconnecting,
  }) async {
    await _transport.disconnect(reason: 'connection_retry');
    _transport.clearAuthentication();
    _deduplicator.clear();
    _emit(
      _state.copyWith(
        phase: reconnecting
            ? WearableConnectionPhase.reconnecting
            : WearableConnectionPhase.connecting,
        clearFailure: true,
      ),
    );
    final helloFuture = _nextMessage(ProtocolMessageType.hello);
    await _transport.connect(device.webSocketUri);
    final hello = await helloFuture;
    _validateHello(hello, credential.deviceId);
    final nonce = hello.payload['nonce']! as String;
    _remoteSessionSource = '${credential.deviceId}:$nonce';
    final signer = AuthenticatedEnvelopeSigner(sessionNonce: nonce);
    _transport.configureAuthentication(
      signer: (message) => signer.sign(message, credential),
      verifier: (message) => signer.verify(message, credential),
    );
    _emit(_state.copyWith(phase: WearableConnectionPhase.authenticating));
    final authentication = _messageFactory.createWithPayload(
      ProtocolMessageType.authentication,
      (messageId, timestamp) => _authenticator
          .createProof(
            credential: credential,
            nonce: nonce,
            messageId: messageId,
            timestamp: timestamp,
          )
          .toPayload(),
    );
    final acknowledgement = await _transport.send(authentication);
    final parsed = ProtocolAcknowledgement.fromPayload(
      acknowledgement!.payload,
    );
    if (!parsed.applied) {
      throw const WearableRemoteException(
        code: 'authentication_failed',
        message: 'The wearable rejected this device credential',
        retryable: false,
      );
    }
    final settingsFuture = _nextMessage(
      ProtocolMessageType.synchronizeSettings,
    );
    await _sendCommand(ProtocolMessageType.requestCurrentSettings);
    await settingsFuture;
    _emit(
      _state.copyWith(
        phase: _phaseForAssistanceState(
          _state.deviceStatus?.assistanceState ?? WearableAssistanceState.idle,
        ),
        selectedDevice: device,
        clearFailure: true,
      ),
    );

    if (credential.host != device.host ||
        credential.port != device.port ||
        credential.deviceName != device.name) {
      final refreshed = WearableCredential(
        deviceId: credential.deviceId,
        deviceName: device.name,
        host: device.host,
        port: device.port,
        serviceName: device.serviceName,
        clientId: credential.clientId,
        credentialId: credential.credentialId,
        secret: credential.secret,
        createdAt: credential.createdAt,
      );
      await _credentialRepository.write(refreshed);
      _activeCredential = refreshed;
    }
  }

  Future<WearableDevice> _refreshEndpoint(
    WearableCredential credential,
    WearableDevice fallback,
  ) async {
    try {
      final discovered = await _discoveryService.discover(
        timeout: const Duration(seconds: 3),
      );
      for (final candidate in discovered) {
        if (candidate.id == credential.deviceId) return candidate;
      }
    } on Object {
      // Remembered endpoint and manual hostname are explicit fallback paths
      // when mDNS is unavailable; connect retries still report any real error.
    }
    return _resolveLocalEndpoint(fallback);
  }

  Future<WearableDevice> _resolveLocalEndpoint(WearableDevice endpoint) async {
    final resolved = await _discoveryService.resolve(endpoint.host);
    if (resolved == null) {
      throw StateError(
        'The wearable endpoint did not resolve to a private local address',
      );
    }
    return endpoint.copyWith(host: resolved.host);
  }

  @override
  Future<void> startAssistance() async {
    _requirePhase(WearableConnectionPhase.connected);
    _emit(_state.copyWith(phase: WearableConnectionPhase.starting));
    try {
      await _sendCommand(ProtocolMessageType.startAssistance);
      _emit(_state.copyWith(phase: WearableConnectionPhase.running));
    } on Object {
      _emit(_state.copyWith(phase: WearableConnectionPhase.connected));
      rethrow;
    }
  }

  @override
  Future<void> pauseAssistance() async {
    _requirePhase(WearableConnectionPhase.running);
    await _sendCommand(ProtocolMessageType.pauseAssistance);
    _emit(_state.copyWith(phase: WearableConnectionPhase.paused));
  }

  @override
  Future<void> resumeAssistance() async {
    _requirePhase(WearableConnectionPhase.paused);
    await _sendCommand(ProtocolMessageType.resumeAssistance);
    _emit(_state.copyWith(phase: WearableConnectionPhase.running));
  }

  @override
  Future<void> stopAssistance() async {
    if (_state.phase != WearableConnectionPhase.running &&
        _state.phase != WearableConnectionPhase.paused) {
      throw StateError('Wearable assistance is not active');
    }
    final previous = _state.phase;
    _emit(_state.copyWith(phase: WearableConnectionPhase.stopping));
    try {
      await _sendCommand(ProtocolMessageType.stopAssistance);
      _emit(_state.copyWith(phase: WearableConnectionPhase.connected));
    } on Object {
      _emit(_state.copyWith(phase: previous));
      rethrow;
    }
  }

  @override
  Future<void> changeMode(String mode) async {
    if (mode.trim().isEmpty || mode.length > 64) {
      throw ArgumentError.value(mode, 'mode');
    }
    _requireConnected();
    await _sendCommand(ProtocolMessageType.changeMode, payload: {'mode': mode});
  }

  @override
  Future<void> updateSettings(WearableSettingsSnapshot settings) async {
    _requireConnected();
    await _sendCommand(
      ProtocolMessageType.updateSettings,
      payload: settings.toPayload(),
    );
    _emit(_state.copyWith(currentSettings: settings));
  }

  @override
  Future<void> requestCurrentSettings() async {
    _requireConnected();
    await _sendCommand(ProtocolMessageType.requestCurrentSettings);
  }

  Future<ProtocolEnvelope?> _sendCommand(
    ProtocolMessageType type, {
    Map<String, Object?> payload = const {},
  }) {
    final message = _messageFactory.create(type, payload: payload);
    return _transport.send(message);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _intentionalDisconnect = true;
    _reconnectInProgress = false;
    await _transport.disconnect(reason: 'app_disconnect');
    _transport.clearAuthentication();
    _remoteSessionSource = null;
    _emit(
      _state.copyWith(
        phase: _state.selectedDevice == null
            ? WearableConnectionPhase.notConfigured
            : WearableConnectionPhase.disconnected,
        clearTelemetry: true,
        clearFailure: true,
      ),
    );
  }

  @override
  Future<void> forgetDevice() async {
    _ensureUsable();
    final credential = _activeCredential;
    final selected = _state.selectedDevice;
    _intentionalDisconnect = true;
    if (credential != null &&
        _transport.status == WearableTransportStatus.connected) {
      try {
        await _sendCommand(
          ProtocolMessageType.revokeCredential,
          payload: {'credentialId': credential.credentialId},
        );
      } on Object catch (error) {
        final failure = _classify(error);
        _reportFailure(failure, phase: WearableConnectionPhase.unavailable);
        rethrow;
      }
    }
    await _transport.disconnect(reason: 'forget_device');
    if (selected != null) {
      await _credentialRepository.delete(selected.id);
    }
    _activeCredential = null;
    _remoteSessionSource = null;
    _deduplicator.clear();
    _emit(
      WearableSessionState.notConfigured.copyWith(
        discoveredDevices: _state.discoveredDevices,
      ),
    );
  }

  Future<ProtocolEnvelope> _nextMessage(
    ProtocolMessageType type, {
    bool Function(ProtocolEnvelope message)? predicate,
  }) {
    return _transport.messages
        .firstWhere(
          (message) =>
              message.type == type && (predicate == null || predicate(message)),
        )
        .timeout(handshakeTimeout);
  }

  void _handleMessage(ProtocolEnvelope message) {
    if (_disposed) return;
    switch (message.type) {
      case ProtocolMessageType.deviceStatus:
        if (!_acceptServerEvent(message)) return;
        final status = WearableDeviceStatus.fromPayload(message.payload);
        _emit(
          _state.copyWith(
            phase: _phaseForAssistanceState(status.assistanceState),
            deviceStatus: status,
          ),
        );
        _eventController.add(WearableStatusReceived(status));
      case ProtocolMessageType.detectionEvent:
      case ProtocolMessageType.priorityHazardAlert:
        if (!_acceptServerEvent(message)) return;
        final detection = WearableDetectionEvent.fromPayload(message.payload);
        _emit(_state.copyWith(lastDetection: detection));
        _eventController.add(
          WearableDetectionReceived(
            detection,
            isHazard: message.type == ProtocolMessageType.priorityHazardAlert,
          ),
        );
      case ProtocolMessageType.deviceHealth:
        if (!_acceptServerEvent(message)) return;
        final health = WearableDeviceHealth.fromPayload(message.payload);
        _emit(_state.copyWith(deviceHealth: health));
        _eventController.add(WearableHealthReceived(health));
      case ProtocolMessageType.synchronizeSettings:
        if (!_acceptServerEvent(message)) return;
        final incoming = WearableSettingsSnapshot.fromPayload(message.payload);
        final local = _state.currentSettings;
        final resolved = local == null
            ? incoming
            : _settingsResolver.resolve(local, incoming);
        _emit(_state.copyWith(currentSettings: resolved));
        _eventController.add(WearableSettingsReceived(resolved));
        if (local != null && identical(resolved, local) && local != incoming) {
          unawaited(_synchronizeLocalSettings(local));
        }
      case ProtocolMessageType.cameraStatus:
        if (!_acceptServerEvent(message)) return;
        _emit(
          _state.copyWith(
            cameraStatus: WearableComponentStatus.fromPayload(message.payload),
          ),
        );
      case ProtocolMessageType.modelStatus:
        if (!_acceptServerEvent(message)) return;
        _emit(
          _state.copyWith(
            modelStatus: WearableComponentStatus.fromPayload(message.payload),
          ),
        );
      case ProtocolMessageType.cameraError:
      case ProtocolMessageType.modelError:
      case ProtocolMessageType.error:
        final remoteError = ProtocolErrorPayload.fromPayload(message.payload);
        final kind = message.type == ProtocolMessageType.cameraError
            ? WearableFailureKind.camera
            : message.type == ProtocolMessageType.modelError
            ? WearableFailureKind.model
            : WearableFailureKind.device;
        _reportFailure(
          WearableFailure(
            kind: kind,
            code: remoteError.code,
            userMessage: remoteError.message,
            canRetry: remoteError.retryable,
          ),
          phase: WearableConnectionPhase.error,
        );
      case ProtocolMessageType.hello:
      case ProtocolMessageType.authentication:
      case ProtocolMessageType.heartbeat:
      case ProtocolMessageType.enrollmentRequest:
      case ProtocolMessageType.enrollmentResult:
      case ProtocolMessageType.pairRequest:
      case ProtocolMessageType.pairResult:
      case ProtocolMessageType.startAssistance:
      case ProtocolMessageType.pauseAssistance:
      case ProtocolMessageType.resumeAssistance:
      case ProtocolMessageType.stopAssistance:
      case ProtocolMessageType.changeMode:
      case ProtocolMessageType.updateSettings:
      case ProtocolMessageType.requestCurrentSettings:
      case ProtocolMessageType.acknowledgement:
      case ProtocolMessageType.revokeCredential:
      case ProtocolMessageType.gracefulDisconnect:
        break;
    }
  }

  Future<void> _synchronizeLocalSettings(
    WearableSettingsSnapshot settings,
  ) async {
    if (!_state.phase.isConnected) return;
    try {
      await _sendCommand(
        ProtocolMessageType.synchronizeSettings,
        payload: settings.toPayload(),
      );
    } on Object catch (error) {
      _handleTransportError(error, StackTrace.current);
    }
  }

  bool _acceptServerEvent(ProtocolEnvelope message) {
    final source = _remoteSessionSource;
    if (source == null) return false;
    return _deduplicator.accept(
      sourceId: source,
      sequence: message.sequence,
      messageId: message.messageId,
    );
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    final failure = _classify(error);
    if (failure.kind == WearableFailureKind.authentication ||
        failure.kind == WearableFailureKind.incompatibleProtocol) {
      _authenticationRejected = true;
    }
    _reportFailure(failure, phase: _phaseForFailure(failure));
  }

  void _handleTransportStatus(WearableTransportStatus status) {
    if (_disposed ||
        _intentionalDisconnect ||
        _connectionOperation ||
        _authenticationRejected) {
      return;
    }
    if ((status == WearableTransportStatus.error ||
            status == WearableTransportStatus.stale) &&
        _state.phase.isConnected &&
        _state.selectedDevice != null &&
        _activeCredential != null) {
      _emit(_state.copyWith(phase: WearableConnectionPhase.unavailable));
      _beginAutomaticReconnect();
    }
  }

  void _beginAutomaticReconnect() {
    if (_reconnectInProgress || _disposed) return;
    final credential = _activeCredential;
    final device = _state.selectedDevice;
    if (credential == null || device == null) return;
    _reconnectInProgress = true;
    unawaited(
      _reconnectAfterDiscovery(credential, device)
          .catchError((Object _) {})
          .whenComplete(() => _reconnectInProgress = false),
    );
  }

  Future<void> _reconnectAfterDiscovery(
    WearableCredential credential,
    WearableDevice fallback,
  ) async {
    final refreshed = await _refreshEndpoint(credential, fallback);
    _emit(_state.copyWith(selectedDevice: refreshed));
    await _connectWithCredential(credential, refreshed, reconnecting: true);
  }

  WearableDevice _deviceFromHello(
    WearableDevice selected,
    ProtocolEnvelope hello,
  ) {
    _validateHello(hello, null);
    final id = hello.payload['deviceId']! as String;
    if (selected.source != WearableDeviceSource.manual &&
        !selected.id.startsWith('mdns:') &&
        id != selected.id) {
      throw const WearableProtocolException(
        'device_identity_mismatch',
        'The discovered device identity changed during pairing',
      );
    }
    return selected.copyWith(id: id);
  }

  void _validateHello(ProtocolEnvelope hello, String? expectedDeviceId) {
    if (hello.payload['role'] != 'pi') {
      throw const WearableProtocolException(
        'invalid_peer',
        'The WebSocket peer is not a wearable service',
      );
    }
    final supportedVersions = hello.payload['supportedVersions']! as List;
    if (!supportedVersions.contains(ProtocolEnvelope.currentVersion)) {
      throw const WearableProtocolException(
        'incompatible_protocol',
        'The wearable does not support protocol version 1',
      );
    }
    if (expectedDeviceId != null &&
        hello.payload['deviceId'] != expectedDeviceId) {
      throw const WearableProtocolException(
        'device_identity_mismatch',
        'The connected wearable does not match the paired device',
      );
    }
  }

  bool _shouldRetryConnection(Object error) {
    if (error is WearableRemoteException && !error.retryable) return false;
    if (error is WearableProtocolException &&
        (error.code == 'incompatible_protocol' ||
            error.code == 'invalid_authentication_tag' ||
            error.code == 'device_identity_mismatch')) {
      return false;
    }
    return true;
  }

  WearableFailure _classify(
    Object error, {
    WearableFailureKind fallbackKind = WearableFailureKind.network,
  }) {
    if (error is WearableProtocolException) {
      if (error.code == 'incompatible_protocol') {
        return const WearableFailure(
          kind: WearableFailureKind.incompatibleProtocol,
          code: 'incompatible_protocol',
          userMessage:
              'The app and wearable protocol versions are incompatible.',
          canRetry: false,
        );
      }
      if (error.code == 'invalid_authentication_tag' ||
          error.code == 'device_identity_mismatch') {
        return WearableFailure(
          kind: WearableFailureKind.authentication,
          code: error.code,
          userMessage: 'The wearable connection could not be authenticated.',
          canRetry: false,
        );
      }
      return WearableFailure(
        kind: WearableFailureKind.malformedMessage,
        code: error.code,
        userMessage: 'The wearable sent an invalid message.',
        canRetry: false,
      );
    }
    if (error is WearableRemoteException) {
      final pairing =
          error.code.contains('pair') || error.code == 'challenge_expired';
      final authentication =
          error.code.contains('auth') || error.code.contains('credential');
      return WearableFailure(
        kind: pairing
            ? WearableFailureKind.pairingExpired
            : authentication
            ? WearableFailureKind.authentication
            : WearableFailureKind.device,
        code: error.code,
        userMessage: pairing
            ? 'The pairing code was invalid or expired. Generate a new code.'
            : authentication
            ? 'The saved wearable credential was rejected. Pair again.'
            : error.message,
        canRetry: error.retryable,
      );
    }
    if (error is TimeoutException) {
      return const WearableFailure(
        kind: WearableFailureKind.timeout,
        code: 'connection_timeout',
        userMessage: 'The wearable did not respond in time.',
      );
    }
    return WearableFailure(
      kind: fallbackKind,
      code: 'wearable_unavailable',
      userMessage: fallbackKind == WearableFailureKind.discovery
          ? 'No wearable could be found on the local network.'
          : fallbackKind == WearableFailureKind.storage
          ? 'The saved wearable configuration could not be loaded.'
          : 'The wearable is unavailable on the local network.',
    );
  }

  WearableConnectionPhase _phaseForFailure(WearableFailure failure) {
    return switch (failure.kind) {
      WearableFailureKind.incompatibleProtocol =>
        WearableConnectionPhase.incompatible,
      WearableFailureKind.authentication ||
      WearableFailureKind.pairingExpired =>
        WearableConnectionPhase.authenticationFailed,
      WearableFailureKind.discovery ||
      WearableFailureKind.network ||
      WearableFailureKind.timeout ||
      WearableFailureKind.storage => WearableConnectionPhase.unavailable,
      WearableFailureKind.malformedMessage ||
      WearableFailureKind.camera ||
      WearableFailureKind.model ||
      WearableFailureKind.device ||
      WearableFailureKind.unknown => WearableConnectionPhase.error,
    };
  }

  WearableConnectionPhase _phaseForAssistanceState(
    WearableAssistanceState state,
  ) {
    return switch (state) {
      WearableAssistanceState.idle => WearableConnectionPhase.connected,
      WearableAssistanceState.starting => WearableConnectionPhase.starting,
      WearableAssistanceState.running => WearableConnectionPhase.running,
      WearableAssistanceState.paused => WearableConnectionPhase.paused,
      WearableAssistanceState.stopping => WearableConnectionPhase.stopping,
      WearableAssistanceState.hardwareError => WearableConnectionPhase.error,
    };
  }

  void _requirePhase(WearableConnectionPhase phase) {
    _ensureUsable();
    if (_state.phase != phase) {
      throw StateError('Wearable state must be ${phase.name}');
    }
  }

  void _requireConnected() {
    _ensureUsable();
    if (!_state.phase.isConnected) {
      throw StateError('The wearable is not connected');
    }
  }

  void _beginConnectionOperation() {
    if (_connectionOperation) {
      throw StateError('A wearable connection operation is already active');
    }
    _connectionOperation = true;
  }

  void _reportFailure(
    WearableFailure failure, {
    required WearableConnectionPhase phase,
  }) {
    if (_disposed) return;
    _emit(_state.copyWith(phase: phase, failure: failure));
    if (!_eventController.isClosed) {
      _eventController.add(WearableFailureReceived(failure));
    }
  }

  void _emit(WearableSessionState state) {
    if (_disposed) return;
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _requireStrongCredentialSecret(String encoded) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded));
      if (bytes.length < 32) {
        throw const FormatException(
          'Credential secret is shorter than 256 bits',
        );
      }
    } on FormatException {
      throw const WearableProtocolException(
        'invalid_credential',
        'The paired credential is malformed',
      );
    }
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('Wearable repository has been disposed');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _intentionalDisconnect = true;
    await _discoveryService.stop();
    await _transport.disconnect(reason: 'repository_dispose');
    _disposed = true;
    await _messageSubscription.cancel();
    await _statusSubscription.cancel();
    await _transport.dispose();
    await _stateController.close();
    await _eventController.close();
  }
}
