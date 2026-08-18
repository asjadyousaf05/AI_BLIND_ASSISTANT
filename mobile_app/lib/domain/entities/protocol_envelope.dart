import '../enums/protocol_message_type.dart';

class ProtocolEnvelope {
  const ProtocolEnvelope({
    required this.protocolVersion,
    required this.type,
    required this.messageId,
    required this.timestamp,
    required this.sequence,
    required this.payload,
    this.authenticationTag,
  });

  static const int currentVersion = 1;
  static const int maximumEncodedBytes = 64 * 1024;

  final int protocolVersion;
  final ProtocolMessageType type;
  final String messageId;
  final DateTime timestamp;
  final int sequence;
  final Map<String, Object?> payload;
  final String? authenticationTag;

  Map<String, Object?> toMap() => {
    'protocolVersion': protocolVersion,
    'type': type.wireName,
    'messageId': messageId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'sequence': sequence,
    'payload': payload,
    if (authenticationTag != null) 'authenticationTag': authenticationTag,
  };

  ProtocolEnvelope copyWithAuthenticationTag(String authenticationTag) {
    return ProtocolEnvelope(
      protocolVersion: protocolVersion,
      type: type,
      messageId: messageId,
      timestamp: timestamp,
      sequence: sequence,
      payload: payload,
      authenticationTag: authenticationTag,
    );
  }
}

class ProtocolAcknowledgement {
  const ProtocolAcknowledgement({
    required this.requestMessageId,
    required this.applied,
    this.detail,
  });

  final String requestMessageId;
  final bool applied;
  final String? detail;

  Map<String, Object?> toPayload() => {
    'requestMessageId': requestMessageId,
    'applied': applied,
    if (detail != null) 'detail': detail,
  };

  static ProtocolAcknowledgement fromPayload(Map<String, Object?> payload) {
    final requestId = payload['requestMessageId'];
    final applied = payload['applied'];
    final detail = payload['detail'];
    if (requestId is! String ||
        requestId.isEmpty ||
        applied is! bool ||
        (detail != null && detail is! String)) {
      throw const FormatException('Invalid protocol acknowledgement');
    }
    return ProtocolAcknowledgement(
      requestMessageId: requestId,
      applied: applied,
      detail: detail as String?,
    );
  }
}

class ProtocolErrorPayload {
  const ProtocolErrorPayload({
    required this.code,
    required this.message,
    required this.retryable,
    this.requestMessageId,
  });

  final String code;
  final String message;
  final bool retryable;
  final String? requestMessageId;

  Map<String, Object?> toPayload() => {
    'code': code,
    'message': message,
    'retryable': retryable,
    if (requestMessageId != null) 'requestMessageId': requestMessageId,
  };

  static ProtocolErrorPayload fromPayload(Map<String, Object?> payload) {
    final code = payload['code'];
    final message = payload['message'];
    final retryable = payload['retryable'];
    final requestId = payload['requestMessageId'];
    if (code is! String ||
        code.isEmpty ||
        message is! String ||
        message.isEmpty ||
        retryable is! bool ||
        (requestId != null && requestId is! String)) {
      throw const FormatException('Invalid structured protocol error');
    }
    return ProtocolErrorPayload(
      code: code,
      message: message,
      retryable: retryable,
      requestMessageId: requestId as String?,
    );
  }
}
