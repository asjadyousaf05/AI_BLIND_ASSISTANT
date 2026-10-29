import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_blind_assistant/domain/entities/protocol_envelope.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_credential.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_device.dart';
import 'package:ai_blind_assistant/domain/enums/protocol_message_type.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_connection_phase.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_transport_status.dart';
import 'package:ai_blind_assistant/domain/repositories/wearable_credential_repository.dart';
import 'package:ai_blind_assistant/domain/services/wearable_discovery_service.dart';
import 'package:ai_blind_assistant/domain/services/wearable_transport.dart';
import 'package:ai_blind_assistant/infrastructure/networking/bounded_retry_policy.dart';
import 'package:ai_blind_assistant/infrastructure/networking/protocol_exception.dart';
import 'package:ai_blind_assistant/infrastructure/networking/web_socket_wearable_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selecting the remembered Pi preserves trust', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.repository.initialize();
    harness.repository.selectDevice(_device.copyWith(host: '192.168.43.9'));
    expect(harness.repository.state.phase, WearableConnectionPhase.paired);
    await harness.repository.connect();
    expect(harness.transport.enrollmentRequests, 0);
    expect(harness.repository.state.phase, WearableConnectionPhase.connected);
  });

  test('a refreshed manual address restores the existing credential', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.repository.initialize();
    harness.repository.selectDevice(_device.copyWith(id: 'manual:new-address'));
    await harness.repository.enroll();
    await harness.repository.connect();
    expect(harness.transport.enrollmentRequests, 0);
    expect(harness.repository.state.selectedDevice?.id, _device.id);
    expect(harness.repository.state.phase, WearableConnectionPhase.connected);
  });

  test('socket error followed by status error starts one reconnect', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.repository.connect();
    final restored = harness.repository.states
        .firstWhere((state) => state.phase == WearableConnectionPhase.connected)
        .timeout(const Duration(seconds: 1));
    harness.discovery.device = _device.copyWith(host: '192.168.43.9');
    harness.transport.failConnection();
    await restored;
    expect(harness.transport.endpoints, hasLength(2));
    expect(harness.transport.endpoints.last.host, '192.168.43.9');
    expect(harness.credentials.saved?.host, '192.168.43.9');
  });

  test('each retry discovers a changed DHCP address', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.transport.failuresRemaining = 1;
    harness.discovery.onDiscover = (count) {
      if (count == 2) {
        harness.discovery.device = _device.copyWith(host: '192.168.43.9');
      }
    };
    await harness.repository.connect();
    expect(harness.transport.endpoints.map((uri) => uri.host), [
      '192.168.43.2',
      '192.168.43.9',
    ]);
  });

  test('disconnect cancels discovery before any socket opens', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final gate = Completer<List<WearableDevice>>();
    harness.discovery.pending = gate;
    final connecting = harness.repository.connect();
    final cancelled = expectLater(connecting, throwsA(isA<Exception>()));
    await harness.discovery.started.future;
    await harness.repository.disconnect();
    await cancelled;
    gate.complete([_device]);
    await Future<void>.delayed(Duration.zero);
    expect(harness.transport.endpoints, isEmpty);
    expect(
      harness.repository.state.phase,
      WearableConnectionPhase.disconnected,
    );
  });

  test('hostname lookup times out within the bounded retry budget', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final gate = Completer<WearableDevice?>();
    harness.discovery.returnDevices = false;
    harness.discovery.resolutionGate = gate;
    await expectLater(
      harness.repository.connect(),
      throwsA(isA<TimeoutException>()),
    );
    gate.complete(null);
    expect(harness.discovery.count, 3);
    expect(harness.transport.endpoints, isEmpty);
    expect(harness.repository.state.phase, WearableConnectionPhase.unavailable);
    expect(harness.repository.state.failure?.code, 'connection_timeout');
  });

  test('disconnect cancels backoff and prevents the next attempt', () async {
    final harness = _Harness(delay: const Duration(seconds: 1));
    addTearDown(harness.dispose);
    harness.transport.failuresRemaining = 3;
    final connecting = harness.repository.connect();
    final cancelled = expectLater(connecting, throwsA(isA<Exception>()));
    await harness.transport.firstAttempt.future;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await harness.repository.disconnect();
    await cancelled;
    expect(harness.transport.endpoints, hasLength(1));
    expect(
      harness.repository.state.phase,
      WearableConnectionPhase.disconnected,
    );
  });

  test('rejected authentication never reconnects automatically', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.repository.connect();
    harness.transport.rejectAuthentication();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.transport.endpoints, hasLength(1));
    expect(
      harness.repository.state.phase,
      WearableConnectionPhase.authenticationFailed,
    );
  });

  test(
    'a late command acknowledgement cannot restore a disconnected session',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.repository.connect();
      final gate = Completer<ProtocolEnvelope?>();
      harness.transport.commandGate = gate;
      final starting = harness.repository.startAssistance();
      final cancelled = expectLater(starting, throwsA(isA<Exception>()));
      await harness.repository.disconnect();
      gate.complete(null);
      await cancelled;
      expect(
        harness.repository.state.phase,
        WearableConnectionPhase.disconnected,
      );
    },
  );
}

const _device = WearableDevice(
  id: 'pi-recovery',
  name: 'Test Pi',
  host: '192.168.43.2',
  port: 8765,
  source: WearableDeviceSource.manual,
);

class _Harness {
  _Harness({Duration delay = const Duration(milliseconds: 1)}) {
    repository = WebSocketWearableRepository(
      discoveryService: discovery,
      credentialRepository: credentials,
      transport: transport,
      handshakeTimeout: const Duration(milliseconds: 100),
      retryPolicy: BoundedRetryPolicy(
        maximumAttempts: 3,
        baseDelay: delay,
        maximumDelay: delay,
        jitterFraction: 0,
      ),
    );
  }
  final discovery = _Discovery();
  final credentials = _Credentials();
  final transport = _Transport();
  late final WebSocketWearableRepository repository;
  Future<void> dispose() => repository.dispose();
}

class _Discovery implements WearableDiscoveryService {
  WearableDevice device = _device;
  int count = 0;
  void Function(int)? onDiscover;
  Completer<List<WearableDevice>>? pending;
  Completer<WearableDevice?>? resolutionGate;
  bool returnDevices = true;
  final started = Completer<void>();
  @override
  Future<List<WearableDevice>> discover({Duration? timeout}) async {
    if (!started.isCompleted) started.complete();
    count++;
    onDiscover?.call(count);
    return pending == null ? (returnDevices ? [device] : []) : pending!.future;
  }

  @override
  Future<WearableDevice?> resolve(String hostOrServiceName) async =>
      resolutionGate == null ? device : resolutionGate!.future;
  @override
  Future<void> stop() async {}
}

class _Credentials implements WearableCredentialRepository {
  WearableCredential? saved = WearableCredential(
    deviceId: _device.id,
    deviceName: _device.name,
    host: _device.host,
    port: _device.port,
    serviceName: _device.serviceName,
    clientId: 'test-phone',
    credentialId: 'test-credential',
    secret: base64Url.encode(List.filled(32, 1)),
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<WearableCredential?> read(String deviceId) async =>
      saved?.deviceId == deviceId ? saved : null;
  @override
  Future<WearableCredential?> readLastPaired() async => saved;
  @override
  Future<void> write(WearableCredential credential) async => saved = credential;
  @override
  Future<void> delete(String deviceId) async => saved = null;
  @override
  Future<String> getOrCreateClientId() async => 'test-phone';
}

class _Transport implements WearableTransport {
  final _messages = StreamController<ProtocolEnvelope>.broadcast();
  final _statuses = StreamController<WearableTransportStatus>.broadcast();
  final endpoints = <Uri>[];
  final firstAttempt = Completer<void>();
  int failuresRemaining = 0;
  int enrollmentRequests = 0;
  int sequence = 0;
  Completer<ProtocolEnvelope?>? commandGate;
  @override
  WearableTransportStatus status = WearableTransportStatus.disconnected;
  @override
  Stream<ProtocolEnvelope> get messages => _messages.stream;
  @override
  Stream<WearableTransportStatus> get statuses => _statuses.stream;
  void _setStatus(WearableTransportStatus next) {
    status = next;
    _statuses.add(next);
  }

  @override
  Future<void> connect(Uri endpoint) async {
    endpoints.add(endpoint);
    if (!firstAttempt.isCompleted) firstAttempt.complete();
    if (failuresRemaining-- > 0) {
      throw const SocketException('Test network unavailable');
    }
    _setStatus(WearableTransportStatus.connected);
    _messages.add(
      _envelope(ProtocolMessageType.hello, {
        'role': 'pi',
        'deviceId': _device.id,
        'supportedVersions': [1],
        'nonce': 'test-nonce-${endpoints.length}',
        'paired': true,
        'capabilities': <String>[],
      }),
    );
  }

  ProtocolEnvelope _envelope(
    ProtocolMessageType type,
    Map<String, Object?> payload,
  ) => ProtocolEnvelope(
    protocolVersion: 1,
    type: type,
    messageId: 'server-${++sequence}',
    timestamp: DateTime.now().toUtc(),
    sequence: sequence,
    payload: payload,
  );
  @override
  Future<ProtocolEnvelope?> send(
    ProtocolEnvelope message, {
    bool requireAcknowledgement = true,
    Duration? acknowledgementTimeout,
  }) async {
    if (message.type == ProtocolMessageType.startAssistance &&
        commandGate != null) {
      return commandGate!.future;
    }
    if (message.type == ProtocolMessageType.enrollmentRequest) {
      enrollmentRequests++;
    }
    if (message.type == ProtocolMessageType.requestCurrentSettings) {
      _messages.add(
        _envelope(ProtocolMessageType.synchronizeSettings, {
          'version': {
            'revision': 1,
            'updatedAt': '2026-09-28T00:00:00Z',
            'source': 'pi',
            'sourceId': _device.id,
          },
          'confidenceThreshold': 0.5,
          'announcementCooldownSeconds': 3,
          'speechEnabled': true,
          'vibrationEnabled': false,
          'assistanceMode': 'object_detection',
        }),
      );
    }
    return _envelope(ProtocolMessageType.acknowledgement, {
      'requestMessageId': message.messageId,
      'applied': true,
    });
  }

  void failConnection() {
    _messages.addError(const SocketException('Test connection lost'));
    _setStatus(WearableTransportStatus.error);
  }

  void rejectAuthentication() {
    _messages.addError(
      const WearableProtocolException(
        'invalid_authentication_tag',
        'Test rejected credential',
      ),
    );
    _setStatus(WearableTransportStatus.error);
  }

  @override
  void configureAuthentication({
    required WearableEnvelopeSigner signer,
    required WearableEnvelopeVerifier verifier,
  }) {}
  @override
  void clearAuthentication() {}
  @override
  Future<void> disconnect({String reason = 'client_disconnect'}) async =>
      _setStatus(WearableTransportStatus.disconnected);
  @override
  Future<void> dispose() async {
    await _messages.close();
    await _statuses.close();
  }
}
