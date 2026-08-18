import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/entities/wearable_credential.dart';
import '../../domain/entities/protocol_envelope.dart';
import 'protocol_exception.dart';

class WearableAuthenticationProof {
  const WearableAuthenticationProof({
    required this.clientId,
    required this.credentialId,
    required this.nonce,
    required this.clientTimestamp,
    required this.tag,
  });

  final String clientId;
  final String credentialId;
  final String nonce;
  final DateTime clientTimestamp;
  final String tag;

  Map<String, Object?> toPayload() => {
    'clientId': clientId,
    'credentialId': credentialId,
    'nonce': nonce,
    'clientTimestamp': clientTimestamp.toUtc().toIso8601String(),
    'tag': tag,
  };
}

/// Signs authenticated envelopes after pairing/authentication. Pairing and the
/// initial hello remain unsigned; replay rejection is performed separately by
/// sequence/message-ID tracking.
class AuthenticatedEnvelopeSigner {
  const AuthenticatedEnvelopeSigner({required this.sessionNonce});

  final String sessionNonce;

  ProtocolEnvelope sign(
    ProtocolEnvelope envelope,
    WearableCredential credential,
  ) {
    final tag = _tag(envelope, credential.secret);
    return envelope.copyWithAuthenticationTag(tag);
  }

  bool verify(ProtocolEnvelope envelope, WearableCredential credential) {
    final supplied = envelope.authenticationTag;
    if (supplied == null) return false;
    return WearableAuthenticator.constantTimeEquals(
      _decodeHex(_tag(envelope, credential.secret)),
      _decodeHex(supplied),
    );
  }

  String canonicalEnvelope(ProtocolEnvelope envelope) {
    final values = [
      sessionNonce,
      envelope.protocolVersion.toString(),
      envelope.type.wireName,
      envelope.messageId,
      envelope.timestamp.toUtc().toIso8601String(),
      envelope.sequence.toString(),
      _canonicalJson(envelope.payload),
    ];
    final buffer = StringBuffer('envelope-v1');
    for (final value in values) {
      buffer
        ..write('|')
        ..write(utf8.encode(value).length)
        ..write(':')
        ..write(value);
    }
    return buffer.toString();
  }

  String _tag(ProtocolEnvelope envelope, String encodedSecret) {
    final key = _deriveKey(encodedSecret);
    return Hmac(
      sha256,
      key,
    ).convert(utf8.encode(canonicalEnvelope(envelope))).toString();
  }

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }

  static List<int> _decodeSecret(String encoded) {
    try {
      return base64Url.decode(base64Url.normalize(encoded));
    } on FormatException {
      throw const WearableProtocolException(
        'invalid_credential',
        'Credential secret is not valid base64url data',
      );
    }
  }

  static List<int> _deriveKey(String encoded) {
    return sha256.convert(_decodeSecret(encoded)).bytes;
  }

  static List<int> _decodeHex(String value) {
    if (value.length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      return const [];
    }
    return [
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ];
  }
}

/// Creates the version 1 HMAC-SHA256 proof used after the server sends a fresh
/// nonce in `hello`. The canonical input is length-prefixed UTF-8 and ordered:
/// nonce, client ID, credential ID, UTC timestamp, message ID.
class WearableAuthenticator {
  const WearableAuthenticator({
    this.allowedClockSkew = const Duration(minutes: 2),
  });

  final Duration allowedClockSkew;

  WearableAuthenticationProof createProof({
    required WearableCredential credential,
    required String nonce,
    required String messageId,
    required DateTime timestamp,
  }) {
    _validateIdentifier(nonce, 'nonce');
    _validateIdentifier(messageId, 'message ID');
    final utcTimestamp = timestamp.toUtc();
    final canonical = canonicalInput(
      nonce: nonce,
      clientId: credential.clientId,
      credentialId: credential.credentialId,
      timestamp: utcTimestamp,
      messageId: messageId,
    );
    final key = _deriveKey(credential.secret);
    final tag = Hmac(sha256, key).convert(utf8.encode(canonical)).toString();
    return WearableAuthenticationProof(
      clientId: credential.clientId,
      credentialId: credential.credentialId,
      nonce: nonce,
      clientTimestamp: utcTimestamp,
      tag: tag,
    );
  }

  bool verifyProof({
    required WearableAuthenticationProof proof,
    required String messageId,
    required String secret,
    DateTime? now,
  }) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    final delta = currentTime.difference(proof.clientTimestamp.toUtc()).abs();
    if (delta > allowedClockSkew) {
      return false;
    }
    final canonical = canonicalInput(
      nonce: proof.nonce,
      clientId: proof.clientId,
      credentialId: proof.credentialId,
      timestamp: proof.clientTimestamp,
      messageId: messageId,
    );
    final expected = Hmac(
      sha256,
      _deriveKey(secret),
    ).convert(utf8.encode(canonical)).bytes;
    final supplied = _decodeHex(proof.tag);
    return constantTimeEquals(expected, supplied);
  }

  static String canonicalInput({
    required String nonce,
    required String clientId,
    required String credentialId,
    required DateTime timestamp,
    required String messageId,
  }) {
    final values = [
      nonce,
      clientId,
      credentialId,
      timestamp.toUtc().toIso8601String(),
      messageId,
    ];
    final buffer = StringBuffer('v1');
    for (final value in values) {
      buffer
        ..write('|')
        ..write(utf8.encode(value).length)
        ..write(':')
        ..write(value);
    }
    return buffer.toString();
  }

  static bool constantTimeEquals(List<int> first, List<int> second) {
    var difference = first.length ^ second.length;
    final length = first.length > second.length ? first.length : second.length;
    for (var index = 0; index < length; index++) {
      final left = index < first.length ? first[index] : 0;
      final right = index < second.length ? second[index] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }

  static List<int> _decodeSecret(String encoded) {
    try {
      return base64Url.decode(base64Url.normalize(encoded));
    } on FormatException {
      throw const WearableProtocolException(
        'invalid_credential',
        'Credential secret is not valid base64url data',
      );
    }
  }

  static List<int> _deriveKey(String encoded) {
    return sha256.convert(_decodeSecret(encoded)).bytes;
  }

  static List<int> _decodeHex(String value) {
    if (value.length != 64 || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
      return const [];
    }
    return [
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ];
  }

  static void _validateIdentifier(String value, String name) {
    if (value.isEmpty || value.length > 1024) {
      throw WearableProtocolException(
        'invalid_authentication',
        'Authentication $name is invalid',
      );
    }
  }
}
