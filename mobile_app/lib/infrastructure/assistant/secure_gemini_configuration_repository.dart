import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/gemini_configuration.dart';
import '../../domain/repositories/gemini_configuration_repository.dart';

class SecureGeminiConfigurationRepository
    implements GeminiConfigurationRepository {
  static const _channel = MethodChannel('ai_blind_assistant/wearable');
  static const _key = 'assistant_gemini_v1';

  @override
  Future<GeminiConfiguration?> load() async {
    final raw = await _channel.invokeMethod<String>('secureRead', {
      'key': _key,
    });
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final configuration = GeminiConfiguration(
        apiKey: data['api_key'] as String,
        model: data['model'] as String,
      );
      return configuration.isValid ? configuration : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(GeminiConfiguration configuration) async {
    if (!configuration.isValid) {
      throw const FormatException('Enter a valid Gemini key and model name.');
    }
    final saved = await _channel.invokeMethod<bool>('secureWrite', {
      'key': _key,
      'value': jsonEncode({
        'api_key': configuration.apiKey,
        'model': configuration.model,
      }),
    });
    if (saved != true) {
      throw const GeminiStorageException();
    }
  }

  @override
  Future<void> delete() async {
    final deleted = await _channel.invokeMethod<bool>('secureDelete', {
      'key': _key,
    });
    if (deleted != true) throw const GeminiStorageException();
  }
}

class GeminiStorageException implements Exception {
  const GeminiStorageException();

  @override
  String toString() => 'Gemini settings could not be updated securely.';
}
