import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/protocol_envelope.dart';
import '../../domain/entities/wearable_settings_snapshot.dart';
import '../../domain/entities/wearable_telemetry.dart';
import '../../domain/enums/protocol_message_type.dart';
import 'protocol_exception.dart';

class ProtocolCodec {
  const ProtocolCodec();

  static const _envelopeKeys = {
    'protocolVersion',
    'type',
    'messageId',
    'timestamp',
    'sequence',
    'payload',
  };
  static const _optionalEnvelopeKeys = {'authenticationTag'};
  static final RegExp _idPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
  );

  String encode(ProtocolEnvelope envelope) {
    validate(envelope);
    final encoded = jsonEncode(envelope.toMap());
    if (utf8.encode(encoded).length > ProtocolEnvelope.maximumEncodedBytes) {
      throw const WearableProtocolException(
        'message_too_large',
        'Encoded protocol message exceeds 64 KiB',
      );
    }
    return encoded;
  }

  ProtocolEnvelope decode(Object? encoded) {
    final String text;
    if (encoded is String) {
      if (utf8.encode(encoded).length > ProtocolEnvelope.maximumEncodedBytes) {
        throw const WearableProtocolException(
          'message_too_large',
          'Protocol message exceeds 64 KiB',
        );
      }
      text = encoded;
    } else if (encoded is List<int> || encoded is Uint8List) {
      final bytes = encoded as List<int>;
      if (bytes.length > ProtocolEnvelope.maximumEncodedBytes) {
        throw const WearableProtocolException(
          'message_too_large',
          'Protocol message exceeds 64 KiB',
        );
      }
      try {
        text = utf8.decode(bytes, allowMalformed: false);
      } on FormatException {
        throw const WearableProtocolException(
          'malformed_message',
          'Protocol bytes are not valid UTF-8',
        );
      }
    } else {
      throw const WearableProtocolException(
        'malformed_message',
        'WebSocket frames must contain JSON text or UTF-8 bytes',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const WearableProtocolException(
        'malformed_message',
        'Protocol frame is not valid JSON',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WearableProtocolException(
        'malformed_message',
        'Protocol envelope must be a JSON object',
      );
    }
    if (decoded.keys.toSet().difference({
          ..._envelopeKeys,
          ..._optionalEnvelopeKeys,
        }).isNotEmpty ||
        _envelopeKeys.difference(decoded.keys.toSet()).isNotEmpty) {
      throw const WearableProtocolException(
        'malformed_message',
        'Protocol envelope has missing or unknown fields',
      );
    }

    final version = decoded['protocolVersion'];
    final rawType = decoded['type'];
    final messageId = decoded['messageId'];
    final rawTimestamp = decoded['timestamp'];
    final sequence = decoded['sequence'];
    final rawPayload = decoded['payload'];
    final authenticationTag = decoded['authenticationTag'];
    if (version is! int ||
        rawType is! String ||
        messageId is! String ||
        rawTimestamp is! String ||
        sequence is! int ||
        rawPayload is! Map<String, dynamic> ||
        (authenticationTag != null && authenticationTag is! String)) {
      throw const WearableProtocolException(
        'malformed_message',
        'Protocol envelope fields have invalid types',
      );
    }
    if (version != ProtocolEnvelope.currentVersion) {
      throw WearableProtocolException(
        'incompatible_protocol',
        'Protocol version $version is not supported',
      );
    }

    final ProtocolMessageType type;
    try {
      type = ProtocolMessageType.fromWireName(rawType);
    } on FormatException {
      throw WearableProtocolException(
        'unsupported_message_type',
        'Unsupported wearable message type: $rawType',
      );
    }
    final timestamp = _parseUtcTimestamp(rawTimestamp, 'timestamp');
    final envelope = ProtocolEnvelope(
      protocolVersion: version,
      type: type,
      messageId: messageId,
      timestamp: timestamp,
      sequence: sequence,
      payload: Map<String, Object?>.unmodifiable(rawPayload),
      authenticationTag: authenticationTag as String?,
    );
    validate(envelope);
    return envelope;
  }

  void validate(ProtocolEnvelope envelope) {
    if (envelope.protocolVersion != ProtocolEnvelope.currentVersion) {
      throw WearableProtocolException(
        'incompatible_protocol',
        'Protocol version ${envelope.protocolVersion} is not supported',
      );
    }
    if (!_idPattern.hasMatch(envelope.messageId)) {
      throw const WearableProtocolException(
        'invalid_message_id',
        'Message ID is empty or contains invalid characters',
      );
    }
    if (!envelope.timestamp.isUtc) {
      throw const WearableProtocolException(
        'invalid_timestamp',
        'Protocol timestamps must be UTC',
      );
    }
    if (envelope.sequence < 0) {
      throw const WearableProtocolException(
        'invalid_sequence',
        'Protocol sequence cannot be negative',
      );
    }
    final authenticationTag = envelope.authenticationTag;
    if (authenticationTag != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(authenticationTag)) {
      throw const WearableProtocolException(
        'invalid_authentication_tag',
        'Envelope authentication tag must be lowercase HMAC-SHA256 hex',
      );
    }
    _validateJsonValue(envelope.payload, depth: 0);
    try {
      _validatePayload(envelope.type, envelope.payload);
    } on WearableProtocolException {
      rethrow;
    } on Object {
      throw WearableProtocolException(
        'invalid_payload',
        'Invalid ${envelope.type.wireName} payload',
      );
    }
  }

  void _validatePayload(
    ProtocolMessageType type,
    Map<String, Object?> payload,
  ) {
    switch (type) {
      case ProtocolMessageType.hello:
        _expectKeys(
          payload,
          required: {
            'role',
            'deviceId',
            'deviceName',
            'supportedVersions',
            'nonce',
          },
          optional: {'serviceVersion', 'modelName', 'paired', 'capabilities'},
        );
        _expectNonEmptyString(payload, 'deviceId');
        _expectNonEmptyString(payload, 'deviceName');
        _expectNonEmptyString(payload, 'nonce');
        final role = payload['role'];
        if (role != 'phone' && role != 'pi') {
          throw const FormatException('Invalid protocol role');
        }
        final versions = payload['supportedVersions'];
        if (versions is! List ||
            versions.isEmpty ||
            versions.any((version) => version is! int || version < 1)) {
          throw const FormatException('Invalid supported protocol versions');
        }
        final paired = payload['paired'];
        if (paired != null && paired is! bool) {
          throw const FormatException('Invalid hello pairing state');
        }
        final capabilities = payload['capabilities'];
        if (capabilities != null &&
            (capabilities is! List ||
                capabilities.any(
                  (capability) => capability is! String || capability.isEmpty,
                ))) {
          throw const FormatException('Invalid hello capabilities');
        }
      case ProtocolMessageType.authentication:
        _expectKeys(
          payload,
          required: {
            'clientId',
            'credentialId',
            'nonce',
            'clientTimestamp',
            'tag',
          },
        );
        for (final key in payload.keys) {
          _expectNonEmptyString(payload, key);
        }
        _parseUtcTimestamp(
          payload['clientTimestamp']! as String,
          'clientTimestamp',
        );
      case ProtocolMessageType.heartbeat:
        _expectKeys(payload, required: {'kind'}, optional: {'replyTo'});
        final kind = payload['kind'];
        if (kind != 'ping' && kind != 'pong') {
          throw const FormatException('Invalid heartbeat kind');
        }
        if (payload.containsKey('replyTo')) {
          _expectNonEmptyString(payload, 'replyTo');
        }
      case ProtocolMessageType.deviceStatus:
        _expectKeys(
          payload,
          required: {
            'deviceId',
            'assistanceState',
            'assistanceMode',
            'settingsRevision',
            'updatedAt',
          },
        );
        WearableDeviceStatus.fromPayload(payload);
      case ProtocolMessageType.enrollmentRequest:
        _expectKeys(payload, required: {'clientId', 'clientName'});
        _expectNonEmptyString(payload, 'clientId');
        _expectNonEmptyString(payload, 'clientName');
      case ProtocolMessageType.enrollmentResult:
        _validateCredentialResult(payload, successField: 'enrolled');
      case ProtocolMessageType.pairRequest:
        _expectKeys(
          payload,
          required: {'clientId', 'clientName', 'pairingCode'},
        );
        _expectNonEmptyString(payload, 'clientId');
        _expectNonEmptyString(payload, 'clientName');
        _expectNonEmptyString(payload, 'pairingCode');
      case ProtocolMessageType.pairResult:
        _validateCredentialResult(payload, successField: 'paired');
      case ProtocolMessageType.startAssistance:
      case ProtocolMessageType.pauseAssistance:
      case ProtocolMessageType.resumeAssistance:
      case ProtocolMessageType.stopAssistance:
      case ProtocolMessageType.requestCurrentSettings:
        _expectKeys(payload, required: const {});
      case ProtocolMessageType.changeMode:
        _expectKeys(payload, required: {'mode'});
        _expectNonEmptyString(payload, 'mode');
      case ProtocolMessageType.updateSettings:
      case ProtocolMessageType.synchronizeSettings:
        _expectKeys(
          payload,
          required: {
            'version',
            'confidenceThreshold',
            'announcementCooldownSeconds',
            'speechEnabled',
            'vibrationEnabled',
            'assistanceMode',
          },
        );
        WearableSettingsSnapshot.fromPayload(payload);
      case ProtocolMessageType.detectionEvent:
      case ProtocolMessageType.priorityHazardAlert:
        _expectKeys(
          payload,
          required: {
            'sourceDeviceId',
            'frameSequence',
            'classId',
            'className',
            'confidence',
            'boundingBox',
            'direction',
            'capturedAt',
            'priority',
          },
          optional: {
            'feedbackTarget',
            'piAnnounced',
            'alertCategory',
            'relativeProximity',
          },
        );
        WearableDetectionEvent.fromPayload(payload);
      case ProtocolMessageType.cameraStatus:
      case ProtocolMessageType.modelStatus:
        _expectKeys(
          payload,
          required: {'state', 'updatedAt'},
          optional: {'errorCode', 'message'},
        );
        WearableComponentStatus.fromPayload(payload);
      case ProtocolMessageType.cameraError:
      case ProtocolMessageType.modelError:
      case ProtocolMessageType.error:
        _expectKeys(
          payload,
          required: {'code', 'message', 'retryable'},
          optional: {'requestMessageId'},
        );
        ProtocolErrorPayload.fromPayload(payload);
      case ProtocolMessageType.deviceHealth:
        _expectKeys(
          payload,
          required: {
            'deviceId',
            'uptimeSeconds',
            'memoryUsedFraction',
            'cameraState',
            'modelState',
            'measuredAt',
          },
          optional: {
            'cpuUsedFraction',
            'cpuTemperatureCelsius',
            'throttled',
            'underVoltage',
            'powerSource',
            'batteryFraction',
          },
        );
        WearableDeviceHealth.fromPayload(payload);
      case ProtocolMessageType.acknowledgement:
        _expectKeys(
          payload,
          required: {'requestMessageId', 'applied'},
          optional: {'detail'},
        );
        ProtocolAcknowledgement.fromPayload(payload);
      case ProtocolMessageType.revokeCredential:
        _expectKeys(payload, required: {'credentialId'});
        _expectNonEmptyString(payload, 'credentialId');
      case ProtocolMessageType.gracefulDisconnect:
        _expectKeys(payload, required: {'reason'});
        _expectNonEmptyString(payload, 'reason');
    }
  }

  void _validateCredentialResult(
    Map<String, Object?> payload, {
    required String successField,
  }) {
    _expectKeys(
      payload,
      required: {'requestMessageId', successField},
      optional: {'deviceId', 'credentialId', 'credentialSecret', 'errorCode'},
    );
    _expectNonEmptyString(payload, 'requestMessageId');
    final succeeded = payload[successField];
    if (succeeded is! bool) {
      throw const FormatException('Invalid credential result');
    }
    if (succeeded) {
      _expectNonEmptyString(payload, 'deviceId');
      _expectNonEmptyString(payload, 'credentialId');
      _expectNonEmptyString(payload, 'credentialSecret');
      if (payload.containsKey('errorCode')) {
        throw const FormatException(
          'Successful credential issue cannot have an error',
        );
      }
    } else {
      _expectNonEmptyString(payload, 'errorCode');
      if (payload.containsKey('credentialSecret')) {
        throw const FormatException(
          'Failed credential issue cannot include a secret',
        );
      }
    }
  }

  void _expectKeys(
    Map<String, Object?> payload, {
    required Set<String> required,
    Set<String> optional = const {},
  }) {
    final actual = payload.keys.toSet();
    if (required.difference(actual).isNotEmpty ||
        actual.difference({...required, ...optional}).isNotEmpty) {
      throw const FormatException('Payload has missing or unknown fields');
    }
  }

  void _expectNonEmptyString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.isEmpty || value.length > 1024) {
      throw FormatException('Invalid $key');
    }
  }

  DateTime _parseUtcTimestamp(String value, String fieldName) {
    if (!value.endsWith('Z')) {
      throw WearableProtocolException(
        'invalid_timestamp',
        '$fieldName must be an ISO-8601 UTC timestamp',
      );
    }
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw WearableProtocolException(
        'invalid_timestamp',
        '$fieldName must be an ISO-8601 UTC timestamp',
      );
    }
  }

  void _validateJsonValue(Object? value, {required int depth}) {
    if (depth > 16) {
      throw const WearableProtocolException(
        'invalid_payload',
        'Protocol payload nesting is too deep',
      );
    }
    if (value == null || value is String || value is bool || value is int) {
      return;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw const WearableProtocolException(
          'invalid_payload',
          'Protocol numbers must be finite',
        );
      }
      return;
    }
    if (value is List) {
      for (final item in value) {
        _validateJsonValue(item, depth: depth + 1);
      }
      return;
    }
    if (value is Map<String, Object?>) {
      for (final entry in value.entries) {
        if (entry.key.isEmpty || entry.key.length > 128) {
          throw const WearableProtocolException(
            'invalid_payload',
            'Protocol payload contains an invalid key',
          );
        }
        _validateJsonValue(entry.value, depth: depth + 1);
      }
      return;
    }
    throw const WearableProtocolException(
      'invalid_payload',
      'Protocol payload contains a non-JSON value',
    );
  }
}
