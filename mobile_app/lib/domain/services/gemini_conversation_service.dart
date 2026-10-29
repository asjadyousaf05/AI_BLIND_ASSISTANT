import '../entities/assistant_message.dart';
import '../entities/gemini_configuration.dart';

/// Text answers only. This boundary cannot upload audio/images or execute tools.
abstract interface class GeminiConversationService {
  Future<String> reply({
    required GeminiConfiguration configuration,
    required String query,
    required List<AssistantMessage> history,
  });

  void cancelPending();
}

class GeminiConversationException implements Exception {
  const GeminiConversationException(this.message);
  final String message;

  @override
  String toString() => message;
}
