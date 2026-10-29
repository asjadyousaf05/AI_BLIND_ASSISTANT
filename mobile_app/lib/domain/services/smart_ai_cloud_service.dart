import '../entities/assistant_message.dart';
import 'smart_ai_interaction_policy.dart';
import '../entities/smart_ai_cloud_configuration.dart';

abstract interface class SmartAiCloudService {
  Future<String> transcribe({
    required SmartAiCloudConfiguration configuration,
    required String audioPath,
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  });
  Future<String> reply({
    required SmartAiCloudConfiguration configuration,
    required String transcript,
    required List<AssistantMessage> history,
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  });
  void cancelPending();
}

/// Contains only a user-safe message, never a provider body or credentials.
class SmartAiCloudException implements Exception {
  const SmartAiCloudException(this.message);
  final String message;
  @override
  String toString() => message;
}
