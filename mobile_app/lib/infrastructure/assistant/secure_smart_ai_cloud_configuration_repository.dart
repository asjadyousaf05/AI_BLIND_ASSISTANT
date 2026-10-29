import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/smart_ai_cloud_configuration.dart';
import '../../domain/repositories/smart_ai_cloud_configuration_repository.dart';

class SecureSmartAiCloudConfigurationRepository
    implements SmartAiCloudConfigurationRepository {
  static const _channel = MethodChannel('ai_blind_assistant/wearable');
  static const _key = 'smart_ai_cloud_v1';

  @override
  Future<SmartAiCloudConfiguration?> load() async {
    final raw = await _channel.invokeMethod<String>('secureRead', {
      'key': _key,
    });
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final provider = switch (data['answer_provider']) {
        'groq' => SmartAiAnswerProvider.groq,
        null || 'agentRouter' => SmartAiAnswerProvider.agentRouter,
        _ => throw const FormatException('Unknown Smart AI provider.'),
      };
      final configuration = SmartAiCloudConfiguration(
        groqKey: data['groq_key'] as String,
        routerKey: data['router_key'] as String? ?? '',
        answerProvider: provider,
      );
      return configuration.isValid ? configuration : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(SmartAiCloudConfiguration configuration) async {
    if (!configuration.isValid) {
      throw const FormatException(
        'Enter the personal keys for the selected provider.',
      );
    }
    final saved = await _channel.invokeMethod<bool>('secureWrite', {
      'key': _key,
      'value': jsonEncode({
        'groq_key': configuration.groqKey,
        'router_key': configuration.routerKey,
        'answer_provider': configuration.answerProvider.name,
      }),
    });
    if (saved != true) throw const SmartAiStorageException();
  }

  @override
  Future<void> delete() async {
    final deleted = await _channel.invokeMethod<bool>('secureDelete', {
      'key': _key,
    });
    if (deleted != true) throw const SmartAiStorageException();
  }
}

class SmartAiStorageException implements Exception {
  const SmartAiStorageException();
  @override
  String toString() => 'Smart AI keys could not be updated securely.';
}
