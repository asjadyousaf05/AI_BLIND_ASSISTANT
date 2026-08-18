import 'dart:math';

import '../../domain/entities/protocol_envelope.dart';
import '../../domain/enums/protocol_message_type.dart';

typedef WearableClock = DateTime Function();

class ProtocolMessageFactory {
  ProtocolMessageFactory({
    WearableClock? clock,
    Random? random,
    int initialSequence = 0,
  }) : _clock = clock ?? _utcNow,
       _random = random ?? Random.secure(),
       _nextSequence = initialSequence;

  final WearableClock _clock;
  final Random _random;
  int _nextSequence;

  ProtocolEnvelope create(
    ProtocolMessageType type, {
    Map<String, Object?> payload = const {},
  }) {
    return ProtocolEnvelope(
      protocolVersion: ProtocolEnvelope.currentVersion,
      type: type,
      messageId: _secureId(_random),
      timestamp: _clock().toUtc(),
      sequence: _nextSequence++,
      payload: Map<String, Object?>.unmodifiable(payload),
    );
  }

  ProtocolEnvelope createWithPayload(
    ProtocolMessageType type,
    Map<String, Object?> Function(String messageId, DateTime timestamp) builder,
  ) {
    final messageId = _secureId(_random);
    final timestamp = _clock().toUtc();
    return ProtocolEnvelope(
      protocolVersion: ProtocolEnvelope.currentVersion,
      type: type,
      messageId: messageId,
      timestamp: timestamp,
      sequence: _nextSequence++,
      payload: Map<String, Object?>.unmodifiable(builder(messageId, timestamp)),
    );
  }

  static String _secureId(Random random) {
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}
