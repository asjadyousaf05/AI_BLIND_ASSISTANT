import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/assistant_credential.dart';
import '../../domain/repositories/assistant_credential_repository.dart';

/// Persists assistant pairing credentials with the Android Keystore-backed
/// secure-storage channel already used by Raspberry Pi pairing.
///
/// A one-time migration removes the early experimental SharedPreferences value
/// after it has been encrypted successfully. Credentials are never logged.
class SecureAssistantCredentialRepository
    implements AssistantCredentialRepository {
  static const _channel = MethodChannel('ai_blind_assistant/wearable');
  static const _key = 'assistant_credential_v2';
  static const _legacyKey = 'assistant_credential_v1';

  @override
  Future<AssistantCredential?> loadCredential() async {
    try {
      var raw = await _channel.invokeMethod<String>('secureRead', {
        'key': _key,
      });
      if (raw == null || raw.isEmpty) {
        raw = await _migrateLegacyCredential();
      }
      if (raw == null || raw.isEmpty) return null;
      return _decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCredential(AssistantCredential credential) async {
    final encoded = _encode(credential);
    final saved = await _channel.invokeMethod<bool>('secureWrite', {
      'key': _key,
      'value': encoded,
    });
    if (saved != true) {
      throw PlatformException(
        code: 'secure_storage_write_failed',
        message: 'The assistant credential could not be stored securely.',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKey);
  }

  @override
  Future<void> deleteCredential() async {
    await _channel.invokeMethod<bool>('secureDelete', {'key': _key});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKey);
  }

  @override
  Future<bool> hasPairedCredential() async {
    final credential = await loadCredential();
    return credential?.isValid ?? false;
  }

  Future<String?> _migrateLegacyCredential() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyKey);
    if (legacy == null || legacy.isEmpty) return null;

    // Validate before persisting malformed legacy data into secure storage.
    _decode(legacy);
    final saved = await _channel.invokeMethod<bool>('secureWrite', {
      'key': _key,
      'value': legacy,
    });
    if (saved == true) {
      await prefs.remove(_legacyKey);
      return legacy;
    }
    return null;
  }

  String _encode(AssistantCredential credential) => jsonEncode({
    'backend_url': credential.backendUrl,
    'bearer_token': credential.bearerToken,
    'user_id': credential.userId,
    'display_name': credential.displayName,
    'paired_at': credential.pairedAt.toIso8601String(),
    'protocol_version': credential.protocolVersion,
  });

  AssistantCredential _decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AssistantCredential(
      backendUrl: json['backend_url'] as String,
      bearerToken: json['bearer_token'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? '',
      pairedAt: DateTime.parse(json['paired_at'] as String),
      protocolVersion: json['protocol_version'] as int? ?? 1,
    );
  }
}
