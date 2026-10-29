import 'dart:async';

import 'package:ai_blind_assistant/domain/enums/protocol_message_type.dart';
import 'package:ai_blind_assistant/infrastructure/networking/protocol_codec.dart';
import 'package:ai_blind_assistant/infrastructure/networking/protocol_message_factory.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_transport_status.dart';
import 'package:ai_blind_assistant/infrastructure/networking/web_socket_wearable_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disconnect during initial cleanup prevents a socket opening', () async {
    final connector = _Connector();
    final transport = WebSocketWearableTransport(connector: connector);
    addTearDown(transport.dispose);
    final connecting = transport.connect(Uri.parse('ws://192.168.43.2:8765'));
    final cancelled = expectLater(connecting, throwsStateError);
    await transport.disconnect();
    await cancelled;
    expect(connector.calls, 0);
    expect(transport.status, WearableTransportStatus.disconnected);
  });

  test('late socket readiness cannot restore a cancelled transport', () async {
    final connector = _Connector();
    final transport = WebSocketWearableTransport(connector: connector);
    addTearDown(transport.dispose);
    final connecting = transport.connect(Uri.parse('ws://192.168.43.2:8765'));
    final cancelled = expectLater(connecting, throwsStateError);
    await connector.started.future;
    await transport.disconnect();
    connector.socket.readiness.complete();
    await cancelled;
    expect(connector.socket.closed, isTrue);
    expect(transport.status, WearableTransportStatus.disconnected);
  });

  test(
    'authentication rejection uses a legal application close code',
    () async {
      final connector = _Connector();
      connector.socket.readiness.complete();
      final transport = WebSocketWearableTransport(connector: connector);
      addTearDown(transport.dispose);
      final errors = transport.messages.listen((_) {}, onError: (Object _) {});
      addTearDown(errors.cancel);
      await transport.connect(Uri.parse('ws://127.0.0.1:8765'));
      transport.configureAuthentication(
        signer: (message) => message,
        verifier: (_) => false,
      );
      connector.socket.data.add(
        const ProtocolCodec().encode(
          ProtocolMessageFactory().create(
            ProtocolMessageType.heartbeat,
            payload: {'kind': 'ping'},
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(connector.socket.closeCode, 4003);
      expect(connector.socket.closed, isTrue);
    },
  );
}

class _Connector implements WearableSocketConnector {
  final socket = _Socket();
  final started = Completer<void>();
  int calls = 0;

  @override
  WearableSocket connect(Uri endpoint, {required Duration timeout}) {
    calls++;
    started.complete();
    return socket;
  }
}

class _Socket implements WearableSocket {
  final readiness = Completer<void>();
  final data = StreamController<Object?>.broadcast();
  bool closed = false;
  int? closeCode;

  @override
  Future<void> get ready => readiness.future;
  @override
  Stream<Object?> get stream => data.stream;
  @override
  void add(Object data) {}
  @override
  Future<void> close([int? code, String? reason]) async {
    closeCode = code;
    if (code != null && code != 1000 && (code < 3000 || code > 4999)) {
      throw ArgumentError('Unsupported client close code');
    }
    closed = true;
    if (!data.isClosed) await data.close();
  }
}
