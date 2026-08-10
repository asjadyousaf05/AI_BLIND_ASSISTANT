// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/protocol_envelope.dart';
import '../../domain/enums/protocol_message_type.dart';
import '../../domain/enums/wearable_transport_status.dart';
import '../../domain/services/wearable_transport.dart';
import 'protocol_codec.dart';
import 'protocol_exception.dart';
import 'protocol_message_factory.dart';

abstract interface class WearableSocket {
  Future<void> get ready;

  Stream<Object?> get stream;

  void add(Object data);

  Future<void> close([int? closeCode, String? reason]);
}

abstract interface class WearableSocketConnector {
  WearableSocket connect(Uri endpoint, {required Duration timeout});
}

class IoWearableSocketConnector implements WearableSocketConnector {
  const IoWearableSocketConnector();

  @override
  WearableSocket connect(Uri endpoint, {required Duration timeout}) {
    return _WebSocketChannelAdapter(
      IOWebSocketChannel.connect(endpoint, connectTimeout: timeout),
    );
  }
}

class _WebSocketChannelAdapter implements WearableSocket {
  _WebSocketChannelAdapter(this._channel);

  final WebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  void add(Object data) => _channel.sink.add(data);

  @override
  Future<void> close([int? closeCode, String? reason]) async {
    await _channel.sink.close(closeCode, reason);
  }
}

class WebSocketWearableTransport implements WearableTransport {
  WebSocketWearableTransport({
    ProtocolCodec codec = const ProtocolCodec(),
    ProtocolMessageFactory? messageFactory,
    WearableSocketConnector connector = const IoWearableSocketConnector(),
    this.heartbeatInterval = const Duration(seconds: 10),
    this.staleTimeout = const Duration(seconds: 30),
    this.acknowledgementTimeout = const Duration(seconds: 5),
    this.connectTimeout = const Duration(seconds: 8),
  }) : _codec = codec,
       _messageFactory = messageFactory ?? ProtocolMessageFactory(),
       _connector = connector {
    if (heartbeatInterval <= Duration.zero ||
        staleTimeout <= heartbeatInterval ||
        acknowledgementTimeout <= Duration.zero ||
        connectTimeout <= Duration.zero) {
      throw ArgumentError('Invalid wearable transport timing configuration');
    }
  }

  final ProtocolCodec _codec;
  final ProtocolMessageFactory _messageFactory;
  final WearableSocketConnector _connector;
  final Duration heartbeatInterval;
  final Duration staleTimeout;
  final Duration acknowledgementTimeout;
  final Duration connectTimeout;

  final StreamController<ProtocolEnvelope> _messageController =
      StreamController<ProtocolEnvelope>.broadcast();
  final StreamController<WearableTransportStatus> _statusController =
      StreamController<WearableTransportStatus>.broadcast();
  final Map<String, Completer<ProtocolEnvelope>> _pendingAcknowledgements = {};

  WearableSocket? _socket;
  StreamSubscription<Object?>? _socketSubscription;
  Timer? _heartbeatTimer;
  WearableEnvelopeSigner? _signer;
  WearableEnvelopeVerifier? _verifier;
  DateTime? _lastReceivedAt;
  WearableTransportStatus _status = WearableTransportStatus.disconnected;
  int _generation = 0;
  bool _disposed = false;

  @override
  WearableTransportStatus get status => _status;

  @override
  Stream<WearableTransportStatus> get statuses => _statusController.stream;

  @override
  Stream<ProtocolEnvelope> get messages => _messageController.stream;

  @override
  Future<void> connect(Uri endpoint) async {
    _ensureUsable();
    if (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') {
      throw ArgumentError.value(endpoint, 'endpoint', 'Must be ws or wss');
    }
    if (_status == WearableTransportStatus.connected) {
      return;
    }
    if (_status == WearableTransportStatus.connecting) {
      throw StateError('A wearable connection attempt is already active');
    }

    await _closeCurrentSocket(closeCode: 1000, reason: 'replace_connection');
    final generation = ++_generation;
    _setStatus(WearableTransportStatus.connecting);
    final socket = _connector.connect(endpoint, timeout: connectTimeout);
    _socket = socket;
    _socketSubscription = socket.stream.listen(
      (data) => _handleData(data, generation),
      onError: (Object error, StackTrace stackTrace) {
        _handleSocketError(error, stackTrace, generation);
      },
      onDone: () => _handleSocketDone(generation),
      cancelOnError: false,
    );
    try {
      await socket.ready.timeout(connectTimeout);
      if (_disposed || generation != _generation || _socket != socket) {
        await socket.close(1000, 'superseded');
        throw StateError('Wearable connection was superseded');
      }
      _lastReceivedAt = DateTime.now().toUtc();
      _setStatus(WearableTransportStatus.connected);
      _startHeartbeat(generation);
    } on Object {
      if (generation == _generation) {
        _setStatus(WearableTransportStatus.error);
        await _closeCurrentSocket(closeCode: 1001, reason: 'connect_failed');
      }
      rethrow;
    }
  }

  @override
  void configureAuthentication({
    required WearableEnvelopeSigner signer,
    required WearableEnvelopeVerifier verifier,
  }) {
    _ensureUsable();
    _signer = signer;
    _verifier = verifier;
  }

  @override
  void clearAuthentication() {
    _signer = null;
    _verifier = null;
  }

  @override
  Future<ProtocolEnvelope?> send(
    ProtocolEnvelope message, {
    bool requireAcknowledgement = true,
    Duration? acknowledgementTimeout,
  }) async {
    _ensureUsable();
    if (_status != WearableTransportStatus.connected || _socket == null) {
      throw StateError('Wearable transport is not connected');
    }
    if (requireAcknowledgement &&
        (message.type == ProtocolMessageType.acknowledgement ||
            message.type == ProtocolMessageType.error ||
            message.type == ProtocolMessageType.heartbeat)) {
      throw ArgumentError(
        'This message type cannot request an acknowledgement',
      );
    }

    final secured = _signer?.call(message) ?? message;
    final encoded = _codec.encode(secured);
    if (!requireAcknowledgement) {
      _socket!.add(encoded);
      return null;
    }

    final completer = Completer<ProtocolEnvelope>();
    if (_pendingAcknowledgements.containsKey(secured.messageId)) {
      throw StateError('Message ID is already awaiting an acknowledgement');
    }
    _pendingAcknowledgements[secured.messageId] = completer;
    _socket!.add(encoded);
    final timeout = acknowledgementTimeout ?? this.acknowledgementTimeout;
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw TimeoutException(
        'No acknowledgement for ${secured.type.wireName}',
        timeout,
      );
    } finally {
      _pendingAcknowledgements.remove(secured.messageId);
    }
  }

  void _handleData(Object? data, int generation) {
    if (_disposed || generation != _generation) return;
    final ProtocolEnvelope message;
    try {
      message = _codec.decode(data);
      final verifier = _verifier;
      if (verifier != null && !verifier(message)) {
        throw const WearableProtocolException(
          'invalid_authentication_tag',
          'Inbound envelope authentication failed',
        );
      }
    } on Object catch (error, stackTrace) {
      _messageController.addError(error, stackTrace);
      if (error is WearableProtocolException &&
          error.code == 'invalid_authentication_tag') {
        unawaited(_rejectUnauthenticatedConnection(generation));
      }
      return;
    }
    _lastReceivedAt = DateTime.now().toUtc();

    if (message.type == ProtocolMessageType.acknowledgement) {
      final acknowledgement = ProtocolAcknowledgement.fromPayload(
        message.payload,
      );
      _pendingAcknowledgements
          .remove(acknowledgement.requestMessageId)
          ?.complete(message);
    } else if (message.type == ProtocolMessageType.error) {
      final error = ProtocolErrorPayload.fromPayload(message.payload);
      final requestId = error.requestMessageId;
      if (requestId != null) {
        _pendingAcknowledgements
            .remove(requestId)
            ?.completeError(
              WearableRemoteException(
                code: error.code,
                message: error.message,
                retryable: error.retryable,
                requestMessageId: requestId,
              ),
            );
      }
    } else if (message.type == ProtocolMessageType.heartbeat) {
      _handleHeartbeat(message);
    }
    _messageController.add(message);
  }

  void _handleHeartbeat(ProtocolEnvelope message) {
    if (message.payload['kind'] != 'ping') return;
    final pong = _messageFactory.create(
      ProtocolMessageType.heartbeat,
      payload: {'kind': 'pong', 'replyTo': message.messageId},
    );
    unawaited(send(pong, requireAcknowledgement: false));
  }

  void _startHeartbeat(int generation) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_disposed ||
          generation != _generation ||
          _status != WearableTransportStatus.connected) {
        return;
      }
      final lastReceived = _lastReceivedAt;
      if (lastReceived == null ||
          DateTime.now().toUtc().difference(lastReceived) >= staleTimeout) {
        _setStatus(WearableTransportStatus.stale);
        _messageController.addError(
          TimeoutException('Wearable heartbeat became stale', staleTimeout),
        );
        unawaited(
          _closeCurrentSocket(closeCode: 1001, reason: 'stale_connection'),
        );
        return;
      }
      final ping = _messageFactory.create(
        ProtocolMessageType.heartbeat,
        payload: const {'kind': 'ping'},
      );
      unawaited(send(ping, requireAcknowledgement: false));
    });
  }

  Future<void> _rejectUnauthenticatedConnection(int generation) async {
    if (generation != _generation) return;
    _setStatus(WearableTransportStatus.error);
    await _closeCurrentSocket(closeCode: 1008, reason: 'authentication_failed');
  }

  void _handleSocketError(Object error, StackTrace stackTrace, int generation) {
    if (_disposed || generation != _generation) return;
    _messageController.addError(error, stackTrace);
    _setStatus(WearableTransportStatus.error);
    _failPending(error, stackTrace);
  }

  void _handleSocketDone(int generation) {
    if (_disposed || generation != _generation) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final wasClosing = _status == WearableTransportStatus.closing;
    _socket = null;
    _socketSubscription = null;
    _failPending(
      StateError('Wearable WebSocket closed before acknowledgement'),
      StackTrace.current,
    );
    _setStatus(
      wasClosing
          ? WearableTransportStatus.disconnected
          : WearableTransportStatus.error,
    );
  }

  void _failPending(Object error, StackTrace stackTrace) {
    final completers = _pendingAcknowledgements.values.toList();
    _pendingAcknowledgements.clear();
    for (final completer in completers) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  @override
  Future<void> disconnect({String reason = 'client_disconnect'}) async {
    if (_disposed) return;
    if (_status == WearableTransportStatus.connected && _socket != null) {
      _setStatus(WearableTransportStatus.closing);
      final message = _messageFactory.create(
        ProtocolMessageType.gracefulDisconnect,
        payload: {'reason': reason},
      );
      try {
        final secured = _signer?.call(message) ?? message;
        _socket!.add(_codec.encode(secured));
      } on Object {
        // Continue closing locally; transport shutdown must remain reliable.
      }
    }
    ++_generation;
    await _closeCurrentSocket(closeCode: 1000, reason: reason);
    _setStatus(WearableTransportStatus.disconnected);
  }

  Future<void> _closeCurrentSocket({
    required int closeCode,
    required String reason,
  }) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final subscription = _socketSubscription;
    final socket = _socket;
    _socketSubscription = null;
    _socket = null;
    await subscription?.cancel();
    if (socket != null) {
      try {
        await socket.close(closeCode, reason);
      } on Object {
        // Closing an already-failed socket is best effort.
      }
    }
    _failPending(StateError('Wearable transport closed'), StackTrace.current);
  }

  void _setStatus(WearableTransportStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('Wearable transport has been disposed');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect(reason: 'client_dispose');
    _disposed = true;
    await _messageController.close();
    await _statusController.close();
  }
}
